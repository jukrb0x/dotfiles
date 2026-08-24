# rmux session snapshots: capture layouts and scrollback, restore them later.
#
# rmux has no native session persistence (no resurrect, no continuum, no
# layout files), but it does expose every primitive needed to build one:
# window_layout round-trips through select-layout, and capture-pane reads
# full scrollback. This module wires those together.
#
# Two hard limits, both verified against rmux 0.9 on Windows:
#
#   1. pane_current_path is always the pane's *start* directory. rmux cannot
#      see a `cd` performed inside the shell, so every restored pane opens in
#      whatever directory it was launched with. Templates carry an explicit
#      `cwd:` for this reason; dumps record what rmux reports and mark it.
#   2. Scrollback is restored as inert text, printed by a throwaway process
#      before the real shell starts. It is scrollable but not in shell
#      history, because Nushell owns its own history file.
#
# Commands are never replayed. pane_current_command yields only a process
# name ("node", "git") with no arguments, so a dump cannot know whether that
# `node` was a dev server or a one-shot script -- and re-running a captured
# command line would re-run its side effects (clone, build, rm). Dumps
# therefore leave `cmd` empty; only templates, which you write by hand, name
# commands to launch.

const SNAPSHOT_ROOT = "~/.local/share/rmux/snapshot"
const TEMPLATE_ROOT = "~/.config/rmux/templates"
const KEEP_GENERATIONS = 5

# Fields worth capturing per pane. Kept as one list so dump and the tests
# agree on the format string.
const PANE_FIELDS = [
    "session_name"
    "window_index"
    "window_name"
    "window_layout"
    "window_active"
    "pane_index"
    "pane_active"
    "pane_current_path"
    "pane_current_command"
]

def snapshot-root []: nothing -> string {
    $SNAPSHOT_ROOT | path expand
}

# Read the live server state as a table, one row per pane.
def read-panes []: nothing -> table {
    let fmt = ($PANE_FIELDS | each {|f| $"#{($f)}" } | str join "\u{1f}")

    let raw = (do { ^rmux list-panes -a -F $fmt } | complete)
    if $raw.exit_code != 0 {
        error make {msg: $"rmux list-panes failed: ($raw.stderr | str trim)"}
    }

    $raw.stdout
    | lines
    | where {|l| ($l | str trim) != "" }
    | each {|line|
        let cells = ($line | split row "\u{1f}")
        $PANE_FIELDS | enumerate | reduce --fold {} {|it, acc|
            $acc | insert $it.item ($cells | get -o $it.index | default "")
        }
    }
}

# Capture one pane's full scrollback. -J rejoins wrapped lines, -S - starts at
# the oldest line still in history. Colour is dropped deliberately: the replay
# path prints this through Nushell, and raw escapes would corrupt the display.
def capture-scrollback [target: string]: nothing -> string {
    let res = (do { ^rmux capture-pane -p -J -S - -t $target } | complete)
    if $res.exit_code != 0 { return "" }
    $res.stdout
}

# --- dump ---------------------------------------------------------------

# Capture every live session to a timestamped generation directory.
export def "rmux-dump" [
    --keep: int = 5      # generations to retain
    --quiet              # suppress progress output
]: nothing -> nothing {
    let panes = (read-panes)
    if ($panes | is-empty) {
        if not $quiet { print "No live rmux sessions; nothing to dump." }
        return
    }

    # Nushell has no Date.now() restriction, but format the stamp explicitly so
    # directory names sort lexically.
    let stamp = (date now | format date "%Y%m%d-%H%M%S")
    let root = (snapshot-root)
    let generation = ($root | path join $stamp)
    mkdir ($generation | path join "panes")

    let sessions = (
        $panes
        | group-by session_name
        | items {|name, rows|
            {
                name: $name
                windows: (
                    $rows
                    | group-by window_index
                    | items {|widx, wrows|
                        let first = ($wrows | first)
                        {
                            index: ($widx | into int)
                            name: $first.window_name
                            layout: $first.window_layout
                            active: ($first.window_active == "1")
                            panes: (
                                $wrows | each {|p|
                                    let target = $"($name):($widx).($p.pane_index)"
                                    let text = (capture-scrollback $target)
                                    let file = $"($name)-($widx).($p.pane_index).txt"

                                    if ($text | str trim) != "" {
                                        $text | save -f ($generation | path join "panes" $file)
                                    }

                                    {
                                        index: ($p.pane_index | into int)
                                        active: ($p.pane_active == "1")
                                        # Recorded for reference only -- see the
                                        # module header. Restore ignores this and
                                        # opens panes in $HOME.
                                        reported_cwd: $p.pane_current_path
                                        # Process name at dump time, no arguments.
                                        # Informational; never executed.
                                        observed_command: $p.pane_current_command
                                        scrollback: (if ($text | str trim) != "" { $file } else { null })
                                    }
                                }
                                | sort-by index
                            )
                        }
                    }
                    | sort-by index
                )
            }
        }
    )

    {
        schema_version: 1
        created: $stamp
        # Restoring cwd is impossible: rmux reports the pane start directory,
        # not the shell's working directory. Panes come back in $HOME.
        cwd_is_unreliable: true
        sessions: $sessions
    }
    | to yaml
    | save -f ($generation | path join "sessions.yaml")

    # `latest` is a plain file holding the generation name; Windows symlinks
    # need elevation or developer mode, so this stays portable.
    $stamp | save -f ($root | path join "latest")

    prune-generations $keep

    if not $quiet {
        let n_sessions = ($sessions | length)
        let n_panes = ($panes | length)
        print $"Dumped ($n_sessions) session\(s\), ($n_panes) pane\(s\) to ($generation)"
    }
}

def prune-generations [keep: int]: nothing -> nothing {
    let root = (snapshot-root)
    let generations = (
        ls $root
        | where type == dir
        | get name
        | path basename
        | sort
    )

    let excess = (($generations | length) - $keep)
    if $excess <= 0 { return }

    $generations | first $excess | each {|g|
        rm -rf ($root | path join $g)
    }
    null
}

# --- load ---------------------------------------------------------------

def latest-generation []: nothing -> string {
    let root = (snapshot-root)
    let pointer = ($root | path join "latest")
    if not ($pointer | path exists) {
        error make {msg: $"No snapshot found. Run rmux-dump first. \(looked in ($root)\)"}
    }
    let stamp = (open $pointer | str trim)
    let dir = ($root | path join $stamp)
    if not ($dir | path exists) {
        error make {msg: $"Snapshot pointer names ($stamp), but ($dir) is missing."}
    }
    $dir
}

def session-exists [name: string]: nothing -> bool {
    (do { ^rmux has-session -t $name } | complete | get exit_code) == 0
}

# Build the launch command for a restored pane.
#
# The scrollback is printed by the pane's own shell before it becomes
# interactive, so the text reaches the terminal as *output*. That is the whole
# safety property: nothing is ever typed, so nothing is ever executed.
#
# paste-buffer would be the obvious alternative and is *wrong* -- it injects
# text into the shell's input line, and scrollback is full of newlines, so it
# would replay every captured command in sequence, side effects included.
#
# rmux execs this string directly rather than handing it to a shell, so `a ; b`
# does not work: the pane dies immediately. Everything therefore runs as a
# single `nu -e ... -i` invocation, which executes the setup then stays
# interactive.
def pane-command [scrollback_path: string]: nothing -> string {
    if ($scrollback_path | is-empty) { return "nu" }

    # Forward slashes sidestep Nushell escape parsing: a literal path like
    # C:\Users\... would trip on \U inside the quoted string.
    let literal = ($scrollback_path | str replace --all '\' '/')
    $"nu -e \"open --raw '($literal)' | print\" -i"
}

# Recreate sessions from a snapshot or a template.
export def "rmux-load" [
    name?: string        # session to restore; omit with --all
    --all                # restore every session in the snapshot
    --template           # read from ~/.config/rmux/templates instead
    --generation: string # specific snapshot stamp (default: latest)
    --quiet
]: nothing -> nothing {
    if not $all and ($name | is-empty) {
        error make {msg: "Pass a session name or --all."}
    }

    let sessions = if $template {
        load-template-sessions $name --all=$all
    } else {
        load-snapshot-sessions $name --all=$all --generation=$generation
    }

    for session in $sessions {
        if (session-exists $session.name) {
            if not $quiet { print $"Session ($session.name) already exists; skipping." }
            continue
        }
        restore-session $session --quiet=$quiet
    }
}

def load-snapshot-sessions [
    name?: string
    --all
    --generation: string
]: nothing -> list {
    let dir = if ($generation | is-empty) {
        latest-generation
    } else {
        (snapshot-root) | path join $generation
    }

    let manifest = ($dir | path join "sessions.yaml")
    if not ($manifest | path exists) {
        error make {msg: $"No sessions.yaml in ($dir)."}
    }

    let data = (open $manifest)
    let panes_dir = ($dir | path join "panes")

    # Resolve scrollback filenames to absolute paths up front so the restore
    # step does not need to know about generation layout.
    let sessions = (
        $data.sessions | each {|s|
            $s | update windows ($s.windows | each {|w|
                $w | update panes ($w.panes | each {|p|
                    let file = ($p.scrollback? | default null)
                    $p | upsert resolved_scrollback (
                        if $file == null { "" } else { $panes_dir | path join $file }
                    ) | upsert cwd ""
                })
            })
        }
    )

    if $all { return $sessions }

    let hit = ($sessions | where name == $name)
    if ($hit | is-empty) {
        let available = ($sessions | get name | str join ", ")
        error make {msg: $"Session ($name) not in snapshot. Available: ($available)"}
    }
    $hit
}

def load-template-sessions [name?: string, --all]: nothing -> list {
    let root = ($TEMPLATE_ROOT | path expand)

    let files = if $all {
        if not ($root | path exists) { [] } else {
            ls ($root | path join "*.yaml") | get name
        }
    } else {
        let f = ($root | path join $"($name).yaml")
        if not ($f | path exists) {
            error make {msg: $"No template at ($f)."}
        }
        [$f]
    }

    $files | each {|f|
        let t = (open $f)
        {
            name: ($t.session? | default ($f | path basename | str replace ".yaml" ""))
            windows: (
                $t.windows | enumerate | each {|it|
                    let w = $it.item
                    {
                        index: ($it.index + 1)
                        name: ($w.name? | default "")
                        layout: ($w.layout? | default "")
                        active: ($it.index == 0)
                        panes: (
                            ($w.panes? | default [{}]) | enumerate | each {|pit|
                                {
                                    index: ($pit.index + 1)
                                    active: ($pit.index == 0)
                                    # Templates own the working directory,
                                    # since dumps cannot recover it.
                                    cwd: ($pit.item.cwd? | default ($w.cwd? | default ""))
                                    command: ($pit.item.cmd? | default "")
                                    resolved_scrollback: ""
                                }
                            }
                        )
                    }
                }
            )
        }
    }
}

def restore-session [session: record, --quiet]: nothing -> nothing {
    let windows = ($session.windows | sort-by index)
    let first_window = ($windows | first)

    # Every target below is a window ID (@N) or pane ID (%N), never
    # session:index. The config sets `renumber-windows on`, so indexes shift as
    # windows are created and an index captured a moment ago can already point
    # somewhere else -- that silently dropped a window during testing. IDs are
    # stable for the lifetime of the window.
    mut active_window_id = ""

    for window in $windows {
        let panes = ($window.panes | sort-by index)
        let first_pane = ($panes | first)
        let is_first_window = ($window.index == $first_window.index)

        let window_id = if $is_first_window {
            let id = (
                ^rmux new-session -d -s $session.name -P -F "#{window_id}" ...(cwd-args $first_pane) (pane-launch $first_pane)
                | str trim
            )
            if ($window.name | is-not-empty) {
                ^rmux rename-window -t $id $window.name
            }
            $id
        } else {
            let name_args = if ($window.name | is-not-empty) { ["-n" $window.name] } else { [] }
            ^rmux new-window -d -t $"($session.name):" -P -F "#{window_id}" ...$name_args ...(cwd-args $first_pane) (pane-launch $first_pane)
            | str trim
        }

        # Split evenly for the remaining panes and let select-layout fix the
        # geometry afterwards. Recreating exact sizes as we go fails once a pane
        # is too small to split; this is the approach tmux-resurrect takes.
        mut pane_ids = [$"($window_id).($first_pane.index)"]
        for pane in ($panes | skip 1) {
            let pid = (
                ^rmux split-window -d -t $window_id -P -F "#{pane_id}" ...(cwd-args $pane) (pane-launch $pane)
                | str trim
            )
            $pane_ids = ($pane_ids | append $pid)
        }

        if ($window.layout | is-not-empty) {
            ^rmux select-layout -t $window_id $window.layout
        }

        # Pane IDs line up with the sorted pane list, so the active pane is
        # addressed positionally rather than by an index select-layout may have
        # reshuffled.
        let active_pos = ($panes | enumerate | where {|it| $it.item.active } | get -o 0)
        if $active_pos != null {
            let pid = ($pane_ids | get -o $active_pos.index)
            if $pid != null { ^rmux select-pane -t $pid }
        }

        if $window.active { $active_window_id = $window_id }
    }

    if ($active_window_id | is-not-empty) {
        ^rmux select-window -t $active_window_id
    }

    if not $quiet {
        let n = ($windows | length)
        print $"Restored ($session.name) with ($n) window\(s\)."
    }
}

def cwd-args [pane: record]: nothing -> list {
    let cwd = ($pane.cwd? | default "")
    if ($cwd | is-empty) { return [] }
    ["-c" ($cwd | path expand)]
}

def pane-launch [pane: record]: nothing -> string {
    let cmd = ($pane.command? | default "")
    if ($cmd | is-not-empty) {
        # Template-declared command. -i keeps the pane alive as an interactive
        # shell once the command exits, so quitting lazygit leaves a usable
        # prompt instead of closing the pane.
        let escaped = ($cmd | str replace --all '"' '\"')
        return $"nu -e \"($escaped)\" -i"
    }
    pane-command ($pane.resolved_scrollback? | default "")
}

# Entry point for the PowerShell shims: `nu snapshot.nu dump [--quiet]` and
# `nu snapshot.nu load <name|--all> [--template] [--quiet]`.
#
# Flags must be declared here, not sifted out of ...rest: Nushell validates
# flags against the signature before the body runs, so an undeclared --quiet is
# a parse error the body never gets to see.
def main [
    action: string        # dump | load
    name?: string         # session name, for load
    --all                 # load every session in the snapshot
    --template            # load from ~/.config/rmux/templates
    --generation: string  # specific snapshot stamp
    --quiet
]: nothing -> nothing {
    match $action {
        "dump" => { rmux-dump --quiet=$quiet }
        "load" => {
            rmux-load $name --all=$all --template=$template --generation=$generation --quiet=$quiet
        }
        _ => { error make {msg: $"Unknown action ($action). Use dump or load."} }
    }
}

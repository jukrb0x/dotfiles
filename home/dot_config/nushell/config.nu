# The banner would scroll away the text that rmux-load reprints into a
# restored pane, and it costs startup time on every new pane.
$env.config.show_banner = false

alias lvim = ^nvim -u ($env.LUNARVIM_BASE_DIR | path join init.lua)
alias nvim = lvim

# Git
alias g = git
alias gl = git pull
alias gp = git push
alias gst = git status

# CLI
alias l = ls -a
alias lg = lazygit
alias cat = bat

def --env ccd [] {
    cd (chezmoi source-path | path dirname)
}

# Zoxide
const zoxide_config = if ("~/.zoxide.nu" | path expand | path exists) {
    "~/.zoxide.nu"
} else {
    null
}
source $zoxide_config

# Starship
if (which starship | is-not-empty) {
    let starship_config = ($nu.data-dir | path join vendor autoload starship.nu)
    if not ($starship_config | path exists) {
        mkdir ($nu.data-dir | path join vendor autoload)
        starship init nu | save -f $starship_config
    }
}

const local_config = if ("~/.config/nushell/config.local.nu" | path expand | path exists) {
    "~/.config/nushell/config.local.nu"
} else {
    null
}
source $local_config

# rmux session snapshots. The real implementation lives in snapshot.nu and is
# also reachable from PowerShell via ~/.local/bin/rmux-{dump,load}; these
# wrappers exist so the commands behave like native Nushell commands here.
const rmux_snapshot = if ("~/.config/rmux/snapshot.nu" | path expand | path exists) {
    "~/.config/rmux/snapshot.nu"
} else {
    null
}
use $rmux_snapshot *


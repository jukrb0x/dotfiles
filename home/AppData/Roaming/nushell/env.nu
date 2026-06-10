# LunarVim
$env.XDG_DATA_HOME = $env.APPDATA
$env.XDG_CONFIG_HOME = ($env.USERPROFILE | path join .config)
$env.XDG_CACHE_HOME = $env.TEMP

$env.LUNARVIM_RUNTIME_DIR = ($env.XDG_DATA_HOME | path join lunarvim)
$env.LUNARVIM_CONFIG_DIR = ($env.XDG_CONFIG_HOME | path join lvim)
$env.LUNARVIM_CACHE_DIR = ($env.XDG_CACHE_HOME | path join lvim)
$env.LUNARVIM_BASE_DIR = ($env.LUNARVIM_RUNTIME_DIR | path join lvim)

$env.EDITOR = "lvim"
$env.VISUAL = $env.EDITOR

# fnm
if (which fnm | is-not-empty) {
    fnm env --json | from json | load-env

    let fnm_path = $env.FNM_MULTISHELL_PATH?
    if ($fnm_path != null) {
        let path_entries = if (($env.PATH | describe) == "string") {
            $env.PATH | split row (char esep)
        } else {
            $env.PATH
        }

        $env.PATH = ($path_entries | prepend $fnm_path | uniq)
    }
}

# Zoxide
if (which zoxide | is-not-empty) {
    zoxide init nushell | save -f ~/.zoxide.nu
}

const local_env = if ("~/.config/nushell/env.local.nu" | path expand | path exists) {
    "~/.config/nushell/env.local.nu"
} else {
    null
}
source-env $local_env

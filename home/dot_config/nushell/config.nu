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

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

# Zoxide
if (which zoxide | is-not-empty) {
    if not ("~/.zoxide.nu" | path expand | path exists) {
        zoxide init nushell | save -f ~/.zoxide.nu
    }
    source ~/.zoxide.nu
}

# Starship
if (which starship | is-not-empty) {
    let starship_config = ($nu.data-dir | path join vendor autoload starship.nu)
    if not ($starship_config | path exists) {
        mkdir ($nu.data-dir | path join vendor autoload)
        starship init nu | save -f $starship_config
    }
}

let local_config = ($nu.home-path | path join .config nushell config.local.nu)
if ($local_config | path exists) {
    source ~/.config/nushell/config.local.nu
}

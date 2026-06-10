# Git config

The managed `~/.gitconfig` stores Git behavior and aliases only. It does not
store names, emails, signing keys, company paths, or account-specific settings.

Put identity in `~/.gitconfig.local`, which is included by the managed config
and is not tracked by chezmoi.

Example:

```ini
[user]
    name = Your Name
    email = you@example.com

[commit]
    gpgsign = false
```

If a machine needs multiple identities, keep the folder rules local too:

```ini
[includeIf "gitdir/i:C:/path/to/personal/"]
    path = ~/.gitconfig-personal

[includeIf "gitdir/i:C:/path/to/work/"]
    path = ~/.gitconfig-work
```

Those included files should also remain local-only. They may contain private
names, emails, signing keys, company folders, or account-specific settings.

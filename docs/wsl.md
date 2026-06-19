# WSL

WSL uses the Linux dotfile layer plus a small Ubuntu-specific bootstrap. Tool
choices stay Linux-universal and Homebrew-based; see [linux.md](linux.md) for
the shared shell, editor, and Linuxbrew model.

## Bootstrap

From inside Ubuntu on WSL:

```shell
/bin/bash ./bootstrap/wsl.sh
```

If the WSL user does not have passwordless sudo, install the base Ubuntu
packages from Windows first:

```powershell
wsl.exe -d Ubuntu -u root -- bash -lc "apt-get update && apt-get install -y build-essential ca-certificates curl file git procps zsh"
```

Then run the bootstrap as the normal WSL user:

```shell
/bin/bash ./bootstrap/wsl.sh
```

The bootstrap installs Homebrew for Linux when missing, installs chezmoi through
Homebrew, initializes a normal Linux chezmoi source at
`~/.local/share/chezmoi`, and stops before applying changes.

## WSL Networking

If WSL can resolve DNS and ping external IPs but TCP connections such as `curl`
or `apt-get update` time out, set WSL to `virtioproxy` networking in
`%UserProfile%\.wslconfig`:

```ini
[wsl2]
networkingMode=virtioproxy
dnsTunneling=true
autoProxy=true
```

Restart WSL after changing this file:

```powershell
wsl.exe --shutdown
```

## Shell

Set zsh after installing `zsh`:

```shell
chsh -s "$(command -v zsh)"
```

If `chsh` asks for a password or is unavailable, set the shell from Windows:

```powershell
wsl.exe -d Ubuntu -u root -- chsh -s /usr/bin/zsh jabriel
```

## Local Private Config

Keep WSL-specific values in local files:

- `~/.zshrc.local.pre`
- `~/.zshrc.local`
- `~/.zprofile.local`
- `~/.gitconfig.local`

These are intentionally unmanaged and can hold WSL-specific proxy, Windows
interop, worktree, or credential settings.

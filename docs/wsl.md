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

Review and apply the initialized state in the same shell:

```shell
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
chezmoi diff
chezmoi apply
chsh -s "$(command -v zsh)"
```

The first apply downloads Oh My Zsh, Powerlevel10k, and the configured zsh
plugins through chezmoi externals. Start a new login session after `chsh` to use
zsh. The bootstrap deliberately does not change the login shell itself because
that is an account-level operation and can require an interactive password.

If you do not want to change the current shell environment, use the absolute
chezmoi path instead:

```shell
/home/linuxbrew/.linuxbrew/bin/chezmoi diff
/home/linuxbrew/.linuxbrew/bin/chezmoi apply
```

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

If `chsh` is unavailable or your WSL distribution requires administrator
rights, set the shell from Windows:

```powershell
wsl.exe -d Ubuntu -u root -- chsh -s /usr/bin/zsh jabriel
```

## Docker Engine

Docker is managed by Ubuntu packages and systemd inside WSL, not by Linuxbrew.
Linuxbrew is good for user-level CLI tools, but Docker is a daemon plus
container runtime, networking, cgroups, and socket permissions.

Install or repair Docker Engine from inside WSL:

```shell
chezmoi cd
bash ./scripts/install-wsl-docker.sh
```

Then restart WSL from Windows so group membership is refreshed:

```powershell
wsl.exe --shutdown
```

Open WSL again and verify:

```shell
docker version
docker compose version
docker run --rm hello-world
```

The Docker client should show both `Client` and `Server` details. The Compose
plugin is provided by the `docker-compose-plugin` apt package, so
`~/.docker/config.json` does not need a Linuxbrew plugin directory.

## Local Private Config

Keep WSL-specific values in local files:

- `~/.zshrc.local.pre`
- `~/.zshrc.local`
- `~/.zprofile.local`
- `~/.gitconfig.local`

These are intentionally unmanaged and can hold WSL-specific proxy, Windows
interop, worktree, or credential settings.

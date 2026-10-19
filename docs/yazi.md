# Yazi: editing and terminal previews

One chezmoi-managed configuration lives in `home/dot_config/yazi`, deployed to
`~/.config/yazi` on macOS, Windows and Linux. Windows explicitly sets
`YAZI_CONFIG_HOME` to this directory. Keep `yazi` and `ya` on the same stable
release; this setup targets **26.9.1**.

For an existing older installation, upgrade Yazi first (`brew upgrade yazi` on
macOS, or `winget upgrade --id sxyazi.yazi --exact` on Windows). The required
Windows manifest installs missing tools; it does not upgrade every installed
unversioned package during apply.

The selected theme is the bundled Tokyo Night variant in
`flavors/tokyo-night.yazi`: a blue/purple palette with a muted selection and
borders, readable fallback icons, and matching syntax highlighting. Both theme
modes select it so terminal background detection cannot switch the palette.
The theme and syntax licenses are included with the flavor.
The main area and status bar inherit the terminal's background and opacity,
matching LunarVim's transparent window; selection highlights stay colored.

## Shell directory navigation

Zsh and Nushell provide a `y` wrapper. Run `y` from the current directory or
`y ~/dev` to start at a specific directory (on Windows, for example,
`y C:\Users\Example\dev`). Enter the desired folder in Yazi, then press `q`
to exit and change the calling shell's directory. Press `Q` to exit without
changing the shell directory. Running `yazi` directly does not change the shell
directory.

After applying with chezmoi, start a new shell to load the function. Nushell
must load the managed `~/.config/nushell/config.nu`; check `$nu.config-path`
if the function is missing on Windows.

## Everyday use

- Hover a file to preview it in the right pane. Text/code uses syntax highlighting;
  JSON is formatted, and long lines wrap.
- `Enter` / `o`: use Yazi's native file-type rules. Text/code opens in the editor,
  images/PDFs use the system app, and archives offer extraction.
- `e`: edit the selection directly, regardless of its extension or MIME type.
- `O`: choose an opener. Unknown file types also offer the editor here.
- `Space`: select multiple files; `e` opens them together.
- `J` / `K`: move through the preview; `Tab`: inspect file information.
- `.`: show hidden files, including dotfiles.

The editor is LunarVim when installed, otherwise Neovim. Windows invokes the
managed PowerShell launcher directly, so it works outside an interactive shell
and when the optional LunarVim runtime has not been installed. Yazi escapes each
file argument itself: do not surround `%s` with another pair of quotes.

There is no extension allowlist. Upstream MIME-based openers and previewers are
inherited, including future upstream fixes. The `e` shortcut handles files whose
MIME type is unusual without another config change.

## Preview tools

These are required packages, installed by `chezmoi apply`:

| Preview / feature | Tool |
| --- | --- |
| File-type detection | macOS `file`; Git for Windows `usr/bin/file.exe` |
| Text and source code | Yazi's built-in previewer; no `bat` plugin needed |
| JSON | `jq` |
| Common raster images | Yazi's built-in image decoder |
| SVG | `resvg` |
| HEIC and fonts | ImageMagick (`magick`) |
| PDF pages | Poppler (`pdftoppm`) |
| Video thumbnails | `ffmpeg` / `ffprobe` |
| Archives | 7-Zip (`7zz` on macOS, `7z` on Windows) |
| Image fallback in terminals without graphics | `chafa` (Unicode block rendering) |
| Search and navigation | `fd`, `ripgrep`, `fzf`, `zoxide` |

Homebrew owns these tools on macOS/Linux. Windows uses the existing WinGet and
Scoop manifests; resvg and Chafa come from Scoop's main bucket. Windows sets
`YAZI_FILE_ONE` using Git's actual installation path, including custom locations,
without adding Git's Unix utilities to PATH.

Office documents and arbitrary binary formats have file information previews;
they are not rendered document pages. Markdown previews show highlighted source.
Image formats outside the built-in decoder depend on the installed ImageMagick
codecs. See [Yazi's dependency reference](https://yazi-rs.github.io/docs/installation/).

## Choose a terminal that displays images

- **macOS:** Ghostty or Kitty; iTerm2 also supports native graphics.
- **Windows:** current Windows Terminal (**1.22.10352.0 or newer**) supports Sixel.
- **tmux:** the managed config enables `allow-passthrough` and retains `TERM` /
  `TERM_PROGRAM`. Reload with `tmux source-file ~/.tmux.conf.local`; existing
  clients may need to detach and attach again. Sixel additionally requires a
  tmux build with Sixel support.
- **Other multiplexers (including RMUX/PSMUX):** test Yazi directly in the outer
  terminal first. Image forwarding is a multiplexer capability; installing
  preview tools cannot supply it. No graphics forwarding is assumed here.
- In a terminal without a supported graphics protocol, Chafa provides a lower
  fidelity block preview. Text previews do not need graphics support.

Do not force `TERM` / `TERM_PROGRAM` to pretend to be another terminal.
See [Yazi's terminal support matrix](https://yazi-rs.github.io/docs/image-preview/).

## Apply and diagnose

From the source checkout:

```sh
chezmoi diff
chezmoi apply
```

On Windows, restart the terminal afterwards so it inherits `YAZI_CONFIG_HOME`,
`YAZI_FILE_ONE`, and the updated PATH. Then:

```sh
ya env
ya cache clear
yazi
```

`ya env` shows the loaded config, editor, detected graphics adapter, dependencies,
and the result of a MIME-detection probe. `yazi --debug` was removed in this
release; use `ya env`. A `Chafa` adapter means block rendering, while `Kgp`,
`Iip`, or `Sixel` indicates a native graphics protocol.

If text previews fail, check MIME detection first. On Windows:

```powershell
& $env:YAZI_FILE_ONE -bL --mime-type -- 'C:\path with spaces\example.txt'
```

If text works but PDF/video/SVG previews do not, check their tools in `ya env`.
If all graphical previews fail, compare `ya env` inside and outside the
multiplexer. Clear the preview cache after changing image dimensions or fixing
the preview tools.

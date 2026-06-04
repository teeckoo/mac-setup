# Setup without Homebrew (Intel Mac, non-admin)

For machines where Homebrew isn't usable (old/unsupported macOS, no admin, or
brew only builds slowly from source). Everything below installs into your home
directory — **no admin rights needed**.

Target tested: MacBook Pro 2017, Intel `x86_64`, macOS Ventura 13.

## 1. Run the installer

```sh
curl -fsSL -o install-no-brew.sh \
  https://raw.githubusercontent.com/teeckoo/mac-setup/main/install-no-brew.sh
bash install-no-brew.sh
rm install-no-brew.sh
```

Installs into `~/.local/bin` (static binaries) and via official installers:
`gkit`, `ripgrep` (rg), `fd`, `eza`, `git-delta` (delta), `gum`, `glow`,
`pandoc`, `jq`, `bat`, `direnv`, `coursier` (cs), `git-filter-repo`, `uv`,
`starship`, `sdkman`, `TinyTeX`, plus `antidote` and `fzf` for zsh. It resolves
each tool's **latest** release automatically, so there are no pinned versions to
update.

> Note: `coursier`, `direnv`, `bat`, and `tinytex` were flagged in
> `softwares.md` as slow/failing under brew (brew compiled them from source).
> Without brew they install as **prebuilt binaries / a dedicated installer**, so
> they're now fast and need no admin.

> macOS Gatekeeper may quarantine a downloaded binary on first run
> ("cannot be opened"). Clear it with:
> `xattr -dr com.apple.quarantine ~/.local/bin`

## 2. Shell config — brew-free version

The main README sources tools via `$(brew --prefix)`, which doesn't exist here.
Use the split below: environment/PATH in `~/.zprofile` (runs once at login),
interactive setup in `~/.zshrc`. On macOS every Terminal/iTerm tab is a login
shell, so `~/.zprofile` reliably sets your PATH.

`~/.zprofile`

```zsh
# ============================================================
# ~/.zprofile — login shell. Environment & PATH.
# ============================================================

# Binaries installed by install-no-brew.sh
export PATH="$HOME/.local/bin:$PATH"

# SDKMAN (JVM ecosystem)
export SDKMAN_DIR="$HOME/.sdkman"

# Silence direnv's background log output (keeps the prompt clean)
export DIRENV_LOG_FORMAT=""
```

`~/.zshrc`

```zsh
# ============================================================
# ~/.zshrc — every interactive shell.
# ============================================================

# ---- System ----
ulimit -n 4096            # prevent "too many open files"
setopt AUTO_CD            # cd by typing a folder name
chpwd() { ls -C; }        # clean newline + listing after each cd

# ---- Zsh plugins (antidote, cloned to ~/.antidote) ----
source "$HOME/.antidote/antidote.zsh"
antidote load < ~/.zsh_plugins.txt

# ---- Prompt (starship) ----
eval "$(starship init zsh)"

# ---- fzf (installed to ~/.fzf) ----
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ---- direnv ----
eval "$(direnv hook zsh)"

# ---- SDKMAN (keep near the end) ----
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
```

`~/.zsh_plugins.txt` (plugin list, unchanged):

```
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
```

## 3. GUI apps (casks) — drag to `~/Applications`

No admin needed: download, open the `.dmg`/`.zip`, drag the `.app` into
`~/Applications` (create the folder if missing). Direct vendor downloads:

| App | Download |
| --- | --- |
| iTerm2 | https://iterm2.com/downloads.html |
| VS Code | https://code.visualstudio.com/docs/?dv=osx (Intel build) |
| IntelliJ IDEA | https://www.jetbrains.com/idea/download/ (Intel `.dmg`) |
| Google Chrome | https://www.google.com/chrome/ |
| Firefox | https://www.mozilla.org/firefox/ |
| Chromium | https://download-chromium.appspot.com/ |
| Opera | https://www.opera.com/download |
| Slack | https://slack.com/downloads/mac |
| Bruno | https://www.usebruno.com/downloads |

FiraCode Nerd Font (required by starship): download from
https://github.com/ryanoasis/nerd-fonts/releases/latest (`FiraCode.zip`),
unzip, and double-click the `.ttf` files (installs to `~/Library/Fonts`, no admin).

## 4. Tools needing manual handling

- **awscli** — official installer, into your home dir (no admin):
  ```sh
  curl -o AWSCLIV2.pkg https://awscli.amazonaws.com/AWSCLIV2.pkg
  installer -pkg AWSCLIV2.pkg -target CurrentUserHomeDirectory
  rm AWSCLIV2.pkg
  # adds ~/aws-cli; symlink it onto PATH:
  ln -sf "$HOME/aws-cli/aws" "$HOME/.local/bin/aws"
  ```
- **docker + colima** — needs a Linux VM (lima + QEMU). Heavy and awkward
  without admin on this hardware; recommend Docker Desktop or a remote/CI
  docker host instead, or skip if not needed.
- **wget** — no official static mac binary. macOS ships `curl`; use that, or
  build wget from source with Xcode CLT + OpenSSL (slow — same problem brew had).
- **gnupg** — no clean no-admin path. Either install GPG Suite
  (https://gpgtools.org — `.pkg`, needs admin) or build from source. If you only
  need signed git commits, consider SSH-key commit signing instead (no GPG).
- **tree** — use `eza --tree` (already installed) instead.
- **gnu-sed** — no prebuilt mac binary; install via `uv`/pip
  (`uv tool install ...`) is not available. If you need GNU sed specifically,
  build from source with Xcode Command Line Tools; otherwise BSD `sed` ships
  with macOS.

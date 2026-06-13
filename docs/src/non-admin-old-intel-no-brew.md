# Non-admin · old Intel (no Homebrew)

An Intel (`x86_64`) Mac with no admin rights, where Homebrew is impractical (it
compiles from source). Everything installs into your home directory — **no brew, no
admin** — via two scripts: `perfect-bottles.sh` (CLI tools as prebuilt binaries) and
`manual-tools.sh` (GUI apps + a few extras).

## 1. Terminal + font first (no admin)

Get iTerm2 and the FiraCode Nerd Font into your home directory, configure iTerm, and
switch to it — then install everything else from inside it. (No `/tmp` on this box, so
downloads go under `~/.cache`.)

```sh
mkdir -p ~/Applications ~/Library/Fonts ~/.cache/dl
# iTerm2 -> ~/Applications (no admin)
curl -fsSL https://iterm2.com/downloads/stable/latest -o ~/.cache/dl/iterm.zip
ditto -x -k ~/.cache/dl/iterm.zip ~/Applications/
xattr -dr com.apple.quarantine ~/Applications/iTerm.app
# FiraCode Nerd Font -> ~/Library/Fonts
curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -o ~/.cache/dl/FiraCode.zip
unzip -qo ~/.cache/dl/FiraCode.zip -d ~/.cache/dl/fc && cp ~/.cache/dl/fc/*.ttf ~/Library/Fonts/
```

{{#include common/iterm.md}}

## 2. Install everything else

From your configured iTerm:

```sh
base=https://raw.githubusercontent.com/teeckoo/mac-setup/main
curl -fsSL "$base/perfect-bottles.sh" | bash     # CLI tools (+ refreshes the font) -> $HOME
curl -fsSL "$base/manual-tools.sh"    | bash     # GUI apps + extras (+ refreshes iTerm2)
```

`perfect-bottles.sh` installs `gkit, rg, gum, glow, pandoc, jq, git-filter-repo, uv,
starship, claude, node`+`npm`/`npx`, `sdk` (SDKMAN), `antidote`, `fzf` (and the
FiraCode font). It auto-loads the shared `lib-no-brew.sh` (local copy if present, else
fetched), so the one-liner works with no clone. The scripts re-install iTerm2 + the
font from step 1 in place — harmless.

{{#include common/gui-apps.md}}

> On Intel, `manual-tools.sh` also installs `coursier` (cs), `direnv`, `bat` as
> prebuilt binaries, `awscli` via the no-admin user pkg, and **container dev**
> (`colima` + `lima` + the `docker` CLI — `colima start --vm-type vz`, no admin).
> It prints guidance for `tinytex` (its installer prompts for admin on Ventura),
> `eza` (no macOS binary — use `ls`), `wget` (use `curl`), and `gnupg` (no no-admin
> path — consider SSH commit signing).

## 3. Shell config (`~/.zprofile` + `~/.zshrc`)

`perfect-bottles.sh` appends both blocks for you (marker-guarded; your own content is
left untouched). Shown here for reference / manual paste:

`~/.zprofile`:

```zsh
# ---- no-brew base config (perfect-bottles.sh) ----
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export DIRENV_LOG_FORMAT=""
```

`~/.zshrc`:

```zsh
# ---- no-brew base config (perfect-bottles.sh) ----
ulimit -n 4096
setopt AUTO_CD
chpwd() { ls -C; }

autoload -Uz compinit
compinit -i               # ignore "insecure" fpath dirs instead of prompting

source "$HOME/.antidote/antidote.zsh"
antidote load < ~/.zsh_plugins.txt
eval "$(starship init zsh)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
# direnv comes from manual-tools.sh; guard makes this a no-op if absent
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
```

> **SDKMAN.** `perfect-bottles.sh` installs SDKMAN into `~/.sdkman` by running its
> **official installer under zsh** — SDKMAN's bash-4 gate only fires under bash, and
> stock Intel macOS has only bash 3.2. SDKMAN's installer appends its own
> `sdkman-init.sh` block to the end of `~/.zshrc` (after `compinit -i`, where it must
> be) — don't add one yourself. Just need a JDK? `cs java --setup` (coursier).

{{#include common/starship.md}}

{{#include common/zsh-plugins.md}}

{{#include common/fzf.md}}

{{#include common/git-pager.md}}

{{#include common/troubleshooting.md}}

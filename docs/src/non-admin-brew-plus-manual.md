# Non-admin · new Mac (Apple Silicon)

You have no admin rights, but Homebrew works here when installed into your home
directory (`~/brew`). Set up your **terminal + font first**, then let **brew handle
the rest** — GUI apps (casks → `~/Applications`, no admin) and the non-problematic
formulae — and **`manual-tools.sh`** install the **manual-install list** (coursier,
direnv, bat, awscli, tinytex) as prebuilt binaries. (Those would otherwise build from
source under `~/brew`'s custom prefix — slow or failing — which is why they're manual.)
Goal:
maximum no-admin, no password prompts.

## 1. Install Homebrew (no admin)

```sh
git clone https://github.com/Homebrew/brew ~/brew
```

Add to `~/.zprofile`, then restart your terminal:

```zsh
eval "$("$HOME"/brew/bin/brew shellenv)"
export HOMEBREW_CASK_OPTS="--appdir=$HOME/Applications"   # casks -> ~/Applications, no admin
```

`HOMEBREW_CASK_OPTS=--appdir` is the key: it makes `brew install --cask …` drop apps
into `~/Applications` instead of `/Applications`, so **no app install asks for an admin
password.**

## 2. Terminal + font first

Install iTerm2 and the FiraCode Nerd Font before anything else, then configure iTerm
and do the rest of the setup from inside it:

```sh
brew install --cask iterm2 font-fira-code-nerd-font
```

{{#include common/iterm.md}}

## 3. The rest via brew

```sh
curl -L -o Brewfile https://raw.githubusercontent.com/teeckoo/mac-setup/main/Brewfile
brew bundle --verbose      # casks (GUI + font) + the non-problematic formulae
rm Brewfile
```

`brew bundle` installs the **GUI apps** as casks (VS Code, IntelliJ, Chrome, Firefox,
Bruno, Slack — into `~/Applications`; re-lists iTerm2 + font, already-installed casks
are skipped) and **the rest of the CLI tools** (gkit, rg, gum, jq, node, sdk,
starship, fzf, antidote, plus containers/cloud/git tools…). All no admin.

> **Why not everything via brew?** Your `~/brew` is a *custom* prefix, so Homebrew
> can't use bottles and **builds formulae from source**. Casks are unaffected
> (prebuilt downloads), and the "rest" formulae build fast enough — but a handful
> are slow or fail to build from source. Those are the **manual-install list**,
> handled next.

## 4. The "install manually" list (prebuilt, not brew)

```sh
curl -fsSL https://raw.githubusercontent.com/teeckoo/mac-setup/main/manual-tools.sh | bash
```

`manual-tools.sh` installs the manual-install list as **prebuilt binaries**
(so they don't source-build under `~/brew`): `coursier` (cs), `direnv`, `bat`,
`awscli`, `tinytex` (no brew formula), `R` (the CRAN build relocated into
`~/.local` — no admin, since the `r` cask prompts for one), `mdbook` (a Rust
build that `~/brew` would compile from source), and **container
dev** — `colima` + `lima` +
the `docker` CLI (`colima start --vm-type vz`, no admin — colima *is* the Docker
engine). It prints guidance for `eza` (no macOS binary — `ls`/`cargo install eza`),
`wget` (use `curl`), and `gnupg` (SSH commit signing).

{{#include common/zshrc-brew.md}}

{{#include common/starship.md}}

{{#include common/zsh-plugins.md}}

{{#include common/fzf.md}}

{{#include common/git-pager.md}}

{{#include common/troubleshooting.md}}

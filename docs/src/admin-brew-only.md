# Admin · new Mac (Homebrew)

You have admin rights on this Mac, so Homebrew does **everything** — CLI tools, GUI
apps (casks), and fonts — from one `Brewfile`. Set up your terminal + font first, then
install the rest from inside iTerm.

## 1. Terminal + font first

```sh
brew install --cask iterm2 font-fira-code-nerd-font
```

{{#include common/iterm.md}}

## 2. Install everything — all brew

```sh
base=https://raw.githubusercontent.com/teeckoo/mac-setup/main
curl -L -o Brewfile       "$base/Brewfile"
curl -L -o Brewfile.admin "$base/Brewfile.admin"
brew bundle --verbose                          # the Brewfile ("the rest"): casks + formulae
brew bundle --verbose --file=Brewfile.admin    # extras: coursier, direnv, wget, awscli, bat,
                                               #   gnupg, eza, mdbook, colima, docker, MacTeX
rm Brewfile Brewfile.admin
```

100% brew, no manual steps. The
[`Brewfile`](https://github.com/teeckoo/mac-setup/blob/main/Brewfile) is "the rest";
[`Brewfile.admin`](https://github.com/teeckoo/mac-setup/blob/main/Brewfile.admin)
holds the packages kept out of it for the non-admin path (they'd source-build under a
non-admin `~/brew`, but bottle fine here). Container dev: `colima start --vm-type vz`,
then `docker …`. LaTeX comes from the `mactex-no-gui` cask (TinyTeX has no Homebrew
formula). The no-admin helper scripts (`perfect-bottles.sh`, `manual-tools.sh`) are
**not needed** on this path.

{{#include common/zshrc-brew.md}}

{{#include common/starship.md}}

{{#include common/zsh-plugins.md}}

{{#include common/fzf.md}}

{{#include common/git-pager.md}}

{{#include common/troubleshooting.md}}

## Shell config (`~/.zprofile` + `~/.zshrc`)

Homebrew is on PATH already (its shellenv), so you only need the interactive block.

`~/.zshrc`:

```zsh
# ---- System ----
ulimit -n 4096            # prevent "too many open files"
setopt AUTO_CD            # cd by typing a folder name
chpwd() { ls -C; }        # listing after each cd
export DIRENV_LOG_FORMAT=""

# ---- Completions (before plugins/SDKMAN, which call compdef) ----
autoload -Uz compinit
compinit -i

# ---- Zsh plugins (antidote) ----
source "$(brew --prefix)/opt/antidote/share/antidote/antidote.zsh"
antidote load < ~/.zsh_plugins.txt

# ---- Prompt (starship) ----
eval "$(starship init zsh)"

# ---- fzf ----
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ---- direnv ----
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# ---- SDKMAN ----
[ -d ~/.sdkman ] && export SDKMAN_DIR="$HOME/.sdkman"
[ -d ~/.sdkman ] || export SDKMAN_DIR="$(brew --prefix sdkman-cli)/libexec"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"
```

Open a new shell to auto-install the plugins.

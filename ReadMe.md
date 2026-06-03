<ins>Install and configure iterm :-</ins>

`brew install --cask iterm2` (if not already installed)

<details><summary>configure iterm global options for non-admin user</summary>

![show tabs](ReadMedia/a.png)

![hide from doc](ReadMedia/b.png)

</details>

---

<details><summary>configure iterm new profile options for non-admin user</summary>

![create new profile](ReadMedia/1.png)


### just provided name visor when profile created

![just provided name visor when profile created](ReadMedia/2.png)

![set visor profile to default](ReadMedia/3.png)

![set color presets](ReadMedia/4.png)

![change font](ReadMedia/5.png)

![change window style](ReadMedia/6.png)

![unlimited terminal scrollback](ReadMedia/7.png)

![z alt_c binding and configure hotkey button](ReadMedia/8.png)

![configure hotkey popup options](ReadMedia/9.png)



</details>

---

<ins>git log on same screen (git shipped with commandline tools) :-</ins>

`git config --global --replace-all core.pager "less -F -X"`


<ins>Configure Zsh plugins :-</ins>

`brew install --cask font-fira-code-nerd-font` (required font by starship, if not already installed)

`brew starship antidote` (if not already installed)

Create `.config/starship.toml`

```
format = """
$directory $git_branch$git_status$all
$character"""

[line_break]
disabled = false

[directory]
truncation_length = 0
truncate_to_repo = false
```


Create:

`~/.zsh_plugins.txt`

Contents:

```
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
```

---

<ins>add below configuration to .zshrc :-</ins>

```
# ============================================================
# 1. System Configurations
# ============================================================

# Prevents file-descriptor leaks and "too many open files" glitches
ulimit -n 4096


# ============================================================
# 2. Antidote Package Manager
# ============================================================

source $(brew --prefix)/opt/antidote/share/antidote/antidote.zsh

# Loads ONLY your clean syntax highlighter and gray text autosuggestions
antidote load < ~/.zsh_plugins.txt


# ============================================================
# 3. Starship Prompt Engine
# ============================================================

# Initializes your multi-line prompt layout
eval "$(starship init zsh)"

# Silences direnv background text output to protect prompt layouts
export DIRENV_LOG_FORMAT=""

# Allows changing directory by typing the folder name directly
setopt AUTO_CD

# Forces a clean newline immediately after you enter a directory,
# pushing the file list down and away from your typed command.
chpwd() {
  ls -C
}
```

open new session to auto install plugins

---

<ins>Configure fzf (one time activity) :-</ins>

`$(brew --prefix)/opt/fzf/install`

Recommended answers

When prompted:

Prompt	Answer
fuzzy auto-completion	yes   
key bindings	yes   
update shell config files	no

---

now refer `softwares.md`

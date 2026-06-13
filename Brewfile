# ============================================================
# Brewfile
# macOS developer workstation — the brew-based install path.
# Use with `brew bundle` (auto-detects ./Brewfile). The brew-free alternative
# (for old Intel / no-admin, where brew compiles from source) is
# perfect-bottles.sh + manual-tools.sh — see README-no-brew.md.
# ============================================================

# ============================================================
# TAPS
# ============================================================

# Additional taps required for specific packages

tap "sdkman/tap"           # sdkman-cli
tap "teeckoo/tap"          # gkit

# ============================================================
# CONTAINERS / VIRTUALIZATION CLIENTS
# ============================================================
# NOTE: colima + the docker CLI are NOT brewed for the non-admin path — a
# non-admin ~/brew (custom prefix) has no bottles and would source-build colima +
# lima + qemu + Go (brutal). They're installed prebuilt by manual-tools.sh (vz
# backend, no admin). Admin: `brew install colima docker` (bottles) — see the guide.


# ============================================================
# CLI PRODUCTIVITY
# ============================================================

brew "gum"
brew "glow"
brew "tree"

brew "jq"
brew "ripgrep"
brew "fd"

# ============================================================
# AI / CODING ASSISTANTS
# ============================================================

cask "claude-code"         # Anthropic's Claude Code CLI

# ============================================================
# GIT / SECURITY
# ============================================================

brew "git-filter-repo"
brew "git-delta"
brew "gkit"                # teeckoo/tap — git/ssh toolkit

# ============================================================
# CLOUD / DEVOPS
# ============================================================



# ============================================================
# DOCS / DIAGRAMMING
# ============================================================

brew "pandoc"

# ============================================================
# LANGUAGE / ECOSYSTEM MANAGERS
# ============================================================

brew "uv"                  # Python ecosystem
brew "sdkman-cli"          # JVM ecosystem
brew "node"                # Node.js runtime + npm/npx



# ============================================================
# UNIX UTILITIES
# ============================================================

brew "gnu-sed"

# ============================================================
# API CLIENT
# ============================================================

cask "bruno"

# ============================================================
# BROWSERS
# ============================================================

cask "google-chrome"
cask "firefox"
cask "chromium"
cask "opera"

# ============================================================
# IDEs / EDITORS
# ============================================================

cask "visual-studio-code"
cask "intellij-idea"

# ============================================================
# COMMUNICATION
# ============================================================

cask "slack"

# ============================================================
# TERMINAL
# ============================================================

cask "iterm2"

# ============================================================
# FONTS
# ============================================================

cask "font-fira-code-nerd-font"   # required by starship; installs to ~/Library/Fonts (no admin)


#!/usr/bin/env bash
# ============================================================
# perfect-bottles.sh
# The brew-free CLI core for an Intel (x86_64) Mac with no admin and no
# Homebrew. Fetches prebuilt static binaries / official curl installers into
# ~/.local/bin. INTEL ONLY: on Apple Silicon use Homebrew (Brewfile) for CLI
# tools instead — brew bottles them fast there — and run manual-tools.sh for the
# no-admin GUI apps. See the setup guide in docs/ (book: teeckoo.github.io/mac-setup).
#
# Companion: manual-tools.sh (no-admin GUI apps + the non-admin manual-install
# extras: coursier, direnv, bat, awscli, tinytex, …). Run one by one:
#     bash perfect-bottles.sh
#     bash manual-tools.sh
# ============================================================
set -uo pipefail

# ---- bootstrap: load the shared library --------------------
# Works with no clone: local copy beside the script if present, else fetch it.
_NB_LIB_URL="https://raw.githubusercontent.com/teeckoo/mac-setup/main/lib-no-brew.sh"
_nb_dir="$(cd "$(dirname "$0")" 2>/dev/null && pwd 2>/dev/null || true)"
if [ -n "${_nb_dir:-}" ] && [ -f "$_nb_dir/lib-no-brew.sh" ]; then
  . "$_nb_dir/lib-no-brew.sh"
else
  _nb_cache="$HOME/.cache/no-brew/tmp"; mkdir -p "$_nb_cache"
  if curl -fsSL "$_NB_LIB_URL" -o "$_nb_cache/lib-no-brew.sh"; then
    . "$_nb_cache/lib-no-brew.sh"
  else
    echo "Could not load lib-no-brew.sh (network?). Aborting." >&2; exit 1
  fi
fi

# Intel-only by design: this is the no-brew path for the old Intel mac. Apple
# Silicon uses Homebrew for CLI tools (see README), so refuse to run there.
if [ "$(uname -m)" != "x86_64" ]; then
  echo "perfect-bottles.sh is the Intel (x86_64) no-brew path; detected $(uname -m)." >&2
  echo "On Apple Silicon: use Homebrew (Brewfile) for CLI tools, then run manual-tools.sh for GUI apps." >&2
  exit 1
fi

require_tools git python3      # antidote/fzf clones + git-filter-repo runtime

# ---- prebuilt CLI binaries (GitHub releases) ---------------
#
# MAINTENANCE: version + filename resolve automatically from each repo's latest
# release. The only thing that ever needs updating is the asset-name regex (the
# middle arg). If a tool renames its files the run prints "! <tool>: API gave no
# asset" — fix that one regex. Confirm at github.com/<owner>/<repo>/releases/latest
# (Intel x86_64 assets, since this script only runs on Intel.)
#
echo "Installing static binaries into $BIN ..."
install_archive BurntSushi/ripgrep 'x86_64-apple-darwin\.tar\.gz' rg
install_archive charmbracelet/gum  'Darwin_x86_64\.tar\.gz'       gum
install_archive charmbracelet/glow 'Darwin_x86_64\.tar\.gz'       glow
install_archive jgm/pandoc         'x86_64-macOS\.zip'            pandoc
install_archive rust-lang/mdBook   'x86_64-apple-darwin\.tar\.gz' mdbook

install_rawbin "https://github.com/jqlang/jq/releases/latest/download/jq-macos-amd64" jq
install_rawbin "https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo" git-filter-repo

# Node.js LTS (bundles npm + npx). Official Intel tarball -> ~/.local/node.
install_node

# ---- official curl installers ------------------------------

echo "Running official installers ..."
# gkit (git/ssh toolkit) -> ~/.cargo/bin via its cargo-dist installer.
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/teeckoo/gkit/releases/latest/download/gkit-installer.sh | sh
# uv (Python ecosystem) -> ~/.local/bin.
curl -LsSf https://astral.sh/uv/install.sh | sh
# starship prompt -> ~/.local/bin.
curl -sS https://starship.rs/install.sh | sh -s -- -b "$BIN" -y
# Claude Code (Anthropic's CLI) -> ~/.local/bin. Native static build under $HOME
# (no admin, no Node), self-verifies a checksum, runs with its own `set -e`, so a
# failure exits that subshell without aborting our run.
if ! curl -fsSL https://claude.ai/install.sh | bash; then
  echo "  ! claude: installer failed (network/region?) — skipped"; FAILED="$FAILED claude"
fi
# Shell config base block (~/.zprofile PATH + ~/.zshrc compinit/plugins) — appended
# before SDKMAN so `compinit -i` precedes the SDKMAN block it appends next.
scaffold_dotfiles
# SDKMAN (for `sdk`) -> ~/.sdkman. Runs the official installer under zsh to clear
# its bash-4 gate; it appends the `sdkman-init.sh` block to ~/.zshrc itself.
install_sdkman
# SDKMAN also wrote its snippet into ~/.bash_profile; nothing reads it in this
# zsh-only setup, so strip it back out (keeps the ~/.zshrc copy).
strip_sdkman_bash_profile

# ---- zsh plugins (replaces brew antidote + fzf) ------------

echo "Setting up zsh plugins ..."
[ -d "$HOME/.antidote" ] || git clone --depth 1 https://github.com/mattmc3/antidote "$HOME/.antidote"
# antidote reads ~/.zsh_plugins.txt; seed it if absent so a fresh account doesn't
# hit "antidote load: no such file". Left alone if you've customized it.
if [ ! -f "$HOME/.zsh_plugins.txt" ]; then
  printf '%s\n' 'zsh-users/zsh-autosuggestions' 'zsh-users/zsh-syntax-highlighting' > "$HOME/.zsh_plugins.txt"
fi
if [ ! -d "$HOME/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf "$HOME/.fzf"
  "$HOME/.fzf/install" --completion --key-bindings --no-update-rc
fi

# ---- FiraCode Nerd Font (required by starship) ------------
# Installs to ~/Library/Fonts (per-user, no admin). On Apple Silicon the font
# comes from brew (font-fira-code-nerd-font cask); here we fetch it directly.
echo "Installing FiraCode Nerd Font ..."
FONT_URL="$(release_urls ryanoasis/nerd-fonts | grep -iE '/FiraCode\.zip$' | head -n1 || true)"
if [ -n "$FONT_URL" ]; then
  ftmp="$(mktemp -d)"
  if curl -fsSL "$FONT_URL" -o "$ftmp/FiraCode.zip"; then
    mkdir -p "$HOME/Library/Fonts"
    unzip -qo "$ftmp/FiraCode.zip" -d "$ftmp/fc" >/dev/null 2>&1
    find "$ftmp/fc" -iname '*.ttf' -exec cp {} "$HOME/Library/Fonts/" \;
    echo "  ✓ FiraCode Nerd Font"
  else
    echo "  ! FiraCode Nerd Font: download failed — skipped"; FAILED="$FAILED FiraCode"
  fi
  rm -rf "$ftmp"
else
  echo "  ! FiraCode Nerd Font: GitHub API gave no asset — skipped"; FAILED="$FAILED FiraCode"
fi

print_summary
echo "Next: run  bash manual-tools.sh  for the GUI apps (Slack, Chrome, VS Code …) and coursier/direnv/bat."

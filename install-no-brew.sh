#!/usr/bin/env bash
# ============================================================
# install-no-brew.sh
# Brew-free setup for an Intel (x86_64) Mac without Homebrew.
# Drops static binaries into ~/.local/bin — no admin required.
# Tested target: MacBook Pro 2017, Intel, macOS Ventura 13.
# ============================================================
set -euo pipefail

BIN="$HOME/.local/bin"
mkdir -p "$BIN"

# ---- helpers ------------------------------------------------

# Print every browser_download_url from a repo's latest release.
release_urls() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -o '"browser_download_url": *"[^"]*"' \
    | sed 's/.*"\(https[^"]*\)".*/\1/'
}

# install_archive <repo> <url-regex-anchored-at-end> <binary-name>
install_archive() {
  local repo="$1" pat="$2" bin="$3" url tmp file found
  url="$(release_urls "$repo" | grep -iE "${pat}\$" | head -n1 || true)"
  if [ -z "$url" ]; then
    echo "  ! $bin: no matching asset in $repo (skipped)"
    return 0
  fi
  tmp="$(mktemp -d)"
  file="$tmp/${url##*/}"
  curl -fsSL "$url" -o "$file"
  case "$file" in
    *.tar.gz|*.tgz) tar -xzf "$file" -C "$tmp" ;;
    *.zip)          unzip -qo "$file" -d "$tmp" ;;
    *)              cp "$file" "$tmp/$bin" ;;
  esac
  found="$(find "$tmp" -type f -name "$bin" | head -n1 || true)"
  if [ -z "$found" ]; then
    echo "  ! $bin: binary not found inside archive (skipped)"
    rm -rf "$tmp"; return 0
  fi
  install -m 0755 "$found" "$BIN/$bin"
  rm -rf "$tmp"
  echo "  ✓ $bin"
}

# install_rawbin <url> <binary-name>
install_rawbin() {
  curl -fsSL "$1" -o "$BIN/$2"
  chmod +x "$BIN/$2"
  echo "  ✓ $2"
}

# install_gzbin <url> <binary-name>   (single gzipped binary, e.g. coursier)
install_gzbin() {
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL "$1" -o "$tmp/b.gz"
  gunzip -c "$tmp/b.gz" > "$BIN/$2"
  chmod +x "$BIN/$2"
  rm -rf "$tmp"
  echo "  ✓ $2"
}

# ---- prebuilt CLI binaries (GitHub releases) ---------------

echo "Installing static binaries into $BIN ..."
install_archive BurntSushi/ripgrep   'x86_64-apple-darwin\.tar\.gz' rg
install_archive sharkdp/fd           'x86_64-apple-darwin\.tar\.gz' fd
install_archive eza-community/eza    'x86_64-apple-darwin\.tar\.gz' eza
install_archive dandavison/delta     'x86_64-apple-darwin\.tar\.gz' delta
install_archive charmbracelet/gum    'Darwin_x86_64\.tar\.gz'       gum
install_archive charmbracelet/glow   'Darwin_x86_64\.tar\.gz'       glow
install_archive jgm/pandoc           'x86_64-macOS\.zip'            pandoc
install_archive sharkdp/bat          'x86_64-apple-darwin\.tar\.gz' bat

install_rawbin "https://github.com/jqlang/jq/releases/latest/download/jq-macos-amd64" jq
install_rawbin "https://github.com/direnv/direnv/releases/latest/download/direnv.darwin-amd64" direnv
install_rawbin "https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo" git-filter-repo
install_gzbin  "https://github.com/coursier/coursier/releases/latest/download/cs-x86_64-apple-darwin.gz" cs

# ---- official curl installers ------------------------------

echo "Running official installers ..."
# gkit (your git/ssh toolkit) -> ~/.local/bin
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/teeckoo/gkit/releases/latest/download/gkit-installer.sh | sh
# uv (Python ecosystem) -> ~/.local/bin
curl -LsSf https://astral.sh/uv/install.sh | sh
# starship prompt -> ~/.local/bin
curl -sS https://starship.rs/install/install.sh | sh -s -- -b "$BIN" -y
# sdkman (JVM ecosystem) -> ~/.sdkman
[ -d "$HOME/.sdkman" ] || curl -s "https://get.sdkman.io" | bash
# TinyTeX (LaTeX, no admin) -> ~/Library/TinyTeX
if [ ! -d "$HOME/Library/TinyTeX" ]; then
  curl -sL "https://yihui.org/tinytex/install-bin-unix.sh" | sh
fi
# expose TinyTeX binaries on PATH (symlink into ~/.local/bin)
TINYTEX_BIN="$HOME/Library/TinyTeX/bin/universal-darwin"
if [ -d "$TINYTEX_BIN" ]; then
  for f in "$TINYTEX_BIN"/*; do ln -sf "$f" "$BIN/$(basename "$f")"; done
fi

# ---- zsh plugins (replaces brew antidote + fzf) ------------

echo "Setting up zsh plugins ..."
[ -d "$HOME/.antidote" ] || git clone --depth 1 https://github.com/mattmc3/antidote "$HOME/.antidote"
if [ ! -d "$HOME/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf "$HOME/.fzf"
  "$HOME/.fzf/install" --completion --key-bindings --no-update-rc
fi

# ---- PATH ---------------------------------------------------

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "
Add this near the top of ~/.zshrc:
  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

echo "
Done. Open a new shell, then check: rg --version, gkit --version, cs version
See README-no-brew section for GUI apps, docker, awscli, and the .zshrc changes."

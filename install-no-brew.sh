#!/usr/bin/env bash
# ============================================================
# install-no-brew.sh
# Brew-free setup for an Intel (x86_64) Mac without Homebrew.
# Drops static binaries into ~/.local/bin — no admin required.
# Tested target: MacBook Pro 2017, Intel, macOS Ventura 13.
# ============================================================
# Best-effort installer: keep going if one tool fails (no `set -e`), but catch
# unset vars and pipe failures. NOTE: must stay compatible with the stock macOS
# /bin/bash 3.2 — avoid empty-array expansion under `set -u` (that bash errors).
set -uo pipefail

# This script ships Intel (x86_64) binaries only.
if [ "$(uname -m)" != "x86_64" ]; then
  echo "This installer targets Intel (x86_64) Macs; detected $(uname -m). Aborting." >&2
  exit 1
fi

# Pre-flight: git (for antidote/fzf clones) and python3 (git-filter-repo runtime)
# come from the Xcode Command Line Tools. Fail early with clear guidance instead
# of dying at the first `git clone` halfway through.
missing=""
command -v git     >/dev/null 2>&1 || missing="$missing git"
command -v python3 >/dev/null 2>&1 || missing="$missing python3"
if [ -n "$missing" ]; then
  echo "Missing required tool(s):$missing" >&2
  echo "These come from the Xcode Command Line Tools. Install them first with:" >&2
  echo "    xcode-select --install" >&2
  echo "(that installer may prompt for admin), then re-run this script." >&2
  exit 1
fi

BIN="$HOME/.local/bin"
mkdir -p "$BIN"

# Keep ALL temp work under $HOME — this user has no access to /tmp or /var.
export TMPDIR="$HOME/.cache/no-brew/tmp"
mkdir -p "$TMPDIR"

# Tools that failed (for the end-of-run summary).
FAILED=""

# ---- helpers ------------------------------------------------

# Print every browser_download_url from a repo's latest release.
# A handful of tools hit this (rg, gum, glow, pandoc, bat, Bruno, FiraCode) —
# still well under GitHub's 60 req/hr anonymous limit. Retries to survive
# transient network drops.
release_urls() {
  local i out
  for i in 1 2 3; do
    out="$(curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
            | grep -o '"browser_download_url": *"[^"]*"' \
            | sed 's/.*"\(https[^"]*\)".*/\1/')"
    [ -n "$out" ] && { printf '%s\n' "$out"; return 0; }
    sleep 3
  done
  return 1
}

# install_archive <repo> <url-regex-anchored-at-end> <binary-name>
install_archive() {
  local repo="$1" pat="$2" bin="$3" url tmp file found
  url="$(release_urls "$repo" | grep -iE "${pat}\$" | head -n1 || true)"
  if [ -z "$url" ]; then
    echo "  ! $bin: GitHub API gave no asset (rate limit or network?) — skipped"
    FAILED="$FAILED $bin"
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

# install_node — official Node.js LTS (bundles npm + npx) into ~/.local/node,
# with node/npm/npx symlinked onto PATH. No admin: global `npm i -g` is pointed
# at ~/.local so packages land in ~/.local/bin (already on PATH) instead of a
# root dir. Idempotent: a rerun replaces ~/.local/node with the latest LTS.
install_node() {
  local ver url tmp top nbin
  # Newest LTS from the dist index. Objects are sorted newest-first; the first
  # one whose "lts" is a quoted codename (not false) is the current LTS release.
  ver="$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null \
          | tr '}' '\n' | grep '"lts":"' | head -n1 \
          | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  if [ -z "$ver" ]; then
    echo "  ! node/npm: could not resolve latest LTS (network?) — skipped"; FAILED="$FAILED node"; return 0
  fi
  url="https://nodejs.org/dist/${ver}/node-${ver}-darwin-x64.tar.gz"
  tmp="$(mktemp -d)"
  if ! curl -fsSL "$url" -o "$tmp/node.tar.gz"; then
    echo "  ! node/npm: download failed (no Intel build for ${ver}?) — skipped"; FAILED="$FAILED node"; rm -rf "$tmp"; return 0
  fi
  if ! tar -xzf "$tmp/node.tar.gz" -C "$tmp"; then
    echo "  ! node/npm: extract failed — skipped"; FAILED="$FAILED node"; rm -rf "$tmp"; return 0
  fi
  top="$(find "$tmp" -maxdepth 1 -type d -name 'node-*-darwin-x64' | head -n1)"
  if [ -z "$top" ]; then
    echo "  ! node/npm: unexpected archive layout — skipped"; FAILED="$FAILED node"; rm -rf "$tmp"; return 0
  fi
  rm -rf "$HOME/.local/node"
  mv "$top" "$HOME/.local/node"
  rm -rf "$tmp"
  nbin="$HOME/.local/node/bin"
  ln -sf "$nbin/node" "$BIN/node"
  ln -sf "$nbin/npm"  "$BIN/npm"
  ln -sf "$nbin/npx"  "$BIN/npx"
  # Send global installs to ~/.local (on PATH, no admin) instead of /usr/local.
  # Run with node on PATH so npm's `#!/usr/bin/env node` shebang resolves.
  PATH="$nbin:$PATH" "$nbin/npm" config set prefix "$HOME/.local" >/dev/null 2>&1
  echo "  ✓ node ${ver} + npm/npx"
}

# install_sdkman — SDKMAN into ~/.sdkman (for `sdk`, e.g. Java versions pinned in
# a direnv .envrc). The official installer hard-aborts on stock bash 3.2
# ("requires Bash 4 or higher"), but that gate is wrapped in `[ -n "$BASH_VERSION" ]`,
# so running the SAME official installer under zsh skips it. The runtime
# (sdkman-init.sh) has no bash-4 features, so `sdk` then works in zsh and in the
# bash 3.2 that direnv uses for .envrc. Best-effort; logged to FAILED on failure.
install_sdkman() {
  local boot="$TMPDIR/sdkman-bootstrap.sh"
  # Primary: official installer under zsh (gate is bash-only -> skipped).
  if curl -fsSL https://get.sdkman.io | zsh; then return 0; fi
  # Fallback (only if zsh ever breaks): same installer under bash with the lone
  # bash-4 gate neutralized (3.x passes a `-lt 0` test); runtime needs no bash 4.
  echo "  sdkman: zsh install failed; retrying under bash with the bash-4 gate neutralized ..."
  if curl -fsSL https://get.sdkman.io -o "$boot" \
     && grep -q 'bash_major_version" -lt 4' "$boot"; then
    sed 's/bash_major_version" -lt 4/bash_major_version" -lt 0/' "$boot" > "$boot.patched"
    if /bin/bash "$boot.patched"; then rm -f "$boot" "$boot.patched"; return 0; fi
  fi
  rm -f "$boot" "$boot.patched" 2>/dev/null
  echo "  ! sdkman: install failed (network?) — skipped"; FAILED="$FAILED sdkman"
  return 0
}

# ---- GUI app helpers (.app -> ~/Applications, no admin) ----
# Casks normally come from brew; here we fetch the vendor .dmg/.zip and drop the
# .app into ~/Applications (writable without admin). Each lands as the latest
# Intel/universal build; the Gatekeeper quarantine flag is cleared so the app
# opens on first launch instead of "cannot be opened".
APPS="$HOME/Applications"

# _place_app <path-to-.app>  — copy into ~/Applications, replacing any old copy.
_place_app() {
  local src="$1" name
  name="$(basename "$src")"
  rm -rf "$APPS/$name"
  cp -R "$src" "$APPS/" || return 1
  xattr -dr com.apple.quarantine "$APPS/$name" 2>/dev/null
  return 0
}

# install_dmg <url> <label>  — download a .dmg, mount it, copy the .app out.
install_dmg() {
  local url="$1" label="$2" tmp dmg out mnt app
  tmp="$(mktemp -d)"; dmg="$tmp/dl.dmg"
  if ! curl -fsSL "$url" -o "$dmg"; then
    echo "  ! $label: download failed (skipped)"; FAILED="$FAILED $label"; rm -rf "$tmp"; return 0
  fi
  # `yes |` auto-accepts any embedded license agreement; -nobrowse hides it from Finder.
  out="$(yes | hdiutil attach -nobrowse -noverify -noautoopen "$dmg" 2>/dev/null)"
  mnt="$(printf '%s\n' "$out" | grep -o '/Volumes/.*' | head -n1)"
  if [ -z "$mnt" ]; then
    echo "  ! $label: could not mount dmg (skipped)"; FAILED="$FAILED $label"; rm -rf "$tmp"; return 0
  fi
  app="$(find "$mnt" -maxdepth 1 -name '*.app' | head -n1)"
  if [ -n "$app" ] && _place_app "$app"; then
    echo "  ✓ $label"
  else
    echo "  ! $label: no .app inside dmg (skipped)"; FAILED="$FAILED $label"
  fi
  hdiutil detach "$mnt" -quiet 2>/dev/null || hdiutil detach "$mnt" -force -quiet 2>/dev/null
  rm -rf "$tmp"
}

# install_appzip <url> <label>  — download a .zip, extract, copy the .app.
install_appzip() {
  local url="$1" label="$2" tmp z app
  tmp="$(mktemp -d)"; z="$tmp/app.zip"
  if ! curl -fsSL "$url" -o "$z"; then
    echo "  ! $label: download failed (skipped)"; FAILED="$FAILED $label"; rm -rf "$tmp"; return 0
  fi
  mkdir -p "$tmp/x"
  ditto -x -k "$z" "$tmp/x" 2>/dev/null || unzip -qo "$z" -d "$tmp/x" >/dev/null 2>&1
  app="$(find "$tmp/x" -maxdepth 2 -name '*.app' | head -n1)"
  if [ -n "$app" ] && _place_app "$app"; then
    echo "  ✓ $label"
  else
    echo "  ! $label: no .app inside zip (skipped)"; FAILED="$FAILED $label"
  fi
  rm -rf "$tmp"
}

# ---- prebuilt CLI binaries (GitHub releases) ---------------
#
# MAINTENANCE: version + filename are resolved automatically from each repo's
# latest release. The ONLY thing that can ever need updating is the middle
# argument — the regex that matches the macOS x86_64 asset name. If a tool
# renames its release files (e.g. drops "x86_64-apple-darwin"), the run prints
# "! <tool>: API gave no asset" and you just fix that one regex. Confirm the new
# name at: https://github.com/<owner>/<repo>/releases/latest
#
echo "Installing static binaries into $BIN ..."
install_archive BurntSushi/ripgrep   'x86_64-apple-darwin\.tar\.gz' rg
install_archive charmbracelet/gum    'Darwin_x86_64\.tar\.gz'       gum
install_archive charmbracelet/glow   'Darwin_x86_64\.tar\.gz'       glow
install_archive jgm/pandoc           'x86_64-macOS\.zip'            pandoc
install_archive sharkdp/bat          'x86_64-apple-darwin\.tar\.gz' bat
# NOTE: fd, eza, delta are intentionally NOT here — their current releases ship
# no Intel (x86_64) macOS binary (eza: none at all; fd/delta: aarch64 only).
# On this Intel Mac use the built-ins instead: ripgrep/find (fd), ls (eza),
# git's pager (delta). Re-add them only if you move to an Apple Silicon Mac.

install_rawbin "https://github.com/jqlang/jq/releases/latest/download/jq-macos-amd64" jq
install_rawbin "https://github.com/direnv/direnv/releases/latest/download/direnv.darwin-amd64" direnv
install_rawbin "https://raw.githubusercontent.com/newren/git-filter-repo/main/git-filter-repo" git-filter-repo
install_gzbin  "https://github.com/coursier/coursier/releases/latest/download/cs-x86_64-apple-darwin.gz" cs

# Node.js LTS (bundles npm + npx). Official Intel tarball -> ~/.local/node.
install_node

# ---- official curl installers ------------------------------

echo "Running official installers ..."
# gkit (your git/ssh toolkit) -> ~/.local/bin
curl --proto '=https' --tlsv1.2 -LsSf \
  https://github.com/teeckoo/gkit/releases/latest/download/gkit-installer.sh | sh
# uv (Python ecosystem) -> ~/.local/bin
curl -LsSf https://astral.sh/uv/install.sh | sh
# starship prompt -> ~/.local/bin
curl -sS https://starship.rs/install.sh | sh -s -- -b "$BIN" -y
# Claude Code (Anthropic's CLI) -> ~/.local/bin. The native installer ships a
# static x86_64 build and installs under $HOME, so no admin and no Node needed.
# It self-verifies a SHA-256 checksum and runs with its own `set -e`, so a
# network/region failure exits that subshell without aborting our run; record it
# in the FAILED summary like the GitHub-release tools.
if ! curl -fsSL https://claude.ai/install.sh | bash; then
  echo "  ! claude: installer failed (network/region?) — skipped"; FAILED="$FAILED claude"
fi
# SDKMAN (for `sdk` — e.g. Java versions pinned in a direnv .envrc) -> ~/.sdkman.
# Runs the official installer under zsh to clear its bash-4 gate (see helper).
install_sdkman
# NOTE: sdkman is intentionally NOT installed — its installer hard-requires
# Bash 4+, but stock macOS ships only Bash 3.2 (and we can't brew a newer one).
# For JDK/JVM version management without brew, use coursier: `cs java --setup`.
# NOTE: TinyTeX is intentionally NOT installed — on this stock macOS its installer
# triggered an admin-password prompt, which breaks the no-admin guarantee. If you
# need LaTeX, install TinyTeX manually (https://yihui.org/tinytex/) and check
# whether your environment still prompts for admin.

# ---- zsh plugins (replaces brew antidote + fzf) ------------

echo "Setting up zsh plugins ..."
[ -d "$HOME/.antidote" ] || git clone --depth 1 https://github.com/mattmc3/antidote "$HOME/.antidote"
if [ ! -d "$HOME/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf "$HOME/.fzf"
  "$HOME/.fzf/install" --completion --key-bindings --no-update-rc
fi

# ---- GUI apps (.app -> ~/Applications) ---------------------
# Big downloads (~2 GB total). Intel/universal builds, resolved to latest at run
# time. Each is best-effort: a failed download is logged and the rest continue.
# NOTE: Opera and Chromium are intentionally omitted — neither offers a clean,
# signed, scriptable Intel download (Chromium ships only unsigned snapshots).
echo "Installing GUI apps into $APPS ..."
mkdir -p "$APPS"
install_appzip "https://iterm2.com/downloads/stable/latest"                                 iTerm2
install_appzip "https://update.code.visualstudio.com/latest/darwin/stable"                  "VS Code"
install_dmg    "https://download.jetbrains.com/product?code=IIU&latest&distribution=mac"    "IntelliJ IDEA"
install_dmg    "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"    "Google Chrome"
install_dmg    "https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=en-US" Firefox
install_dmg    "https://slack.com/ssb/download-osx"                                         Slack
# Bruno: resolve the Intel (x64) dmg from its latest GitHub release.
BRUNO_URL="$(release_urls usebruno/bruno | grep -iE 'x64_mac\.dmg$' | head -n1 || true)"
if [ -n "$BRUNO_URL" ]; then
  install_dmg "$BRUNO_URL" Bruno
else
  echo "  ! Bruno: GitHub API gave no asset (rate limit or network?) — skipped"; FAILED="$FAILED Bruno"
fi

# ---- FiraCode Nerd Font (required by starship) ------------
# Installs to ~/Library/Fonts (per-user, no admin).
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

# ---- PATH ---------------------------------------------------

case ":$PATH:" in
  *":$BIN:"*) ;;
  *) echo "
Add this near the top of ~/.zprofile (gkit lives in ~/.cargo/bin):
  export PATH=\"\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH\"" ;;
esac

if [ -n "$FAILED" ]; then
  echo "
! Skipped (GitHub API unreachable or rate-limited):$FAILED
  Safe to re-run to retry these — installed tools are refreshed to latest in
  place (only antidote/fzf and unreachable tools are skipped):
    bash install-no-brew.sh"
fi

echo "
Done. Open a new shell, then check: rg --version, gkit --version, cs version, claude --version, npm --version
GUI apps were installed into ~/Applications (open one to confirm).
See README-no-brew for docker, awscli, and the .zshrc changes."

#!/usr/bin/env bash
# ============================================================
# lib-no-brew.sh
# Shared library for the brew-free macOS setup. SOURCE this file
# (`. lib-no-brew.sh`) — do not execute it. It defines the env, the
# preflight, every install helper, and the end-of-run summary used by both
#   perfect-bottles.sh  (the clean prebuilt tools)
#   manual-tools.sh     (the non-admin manual-install list + GUI apps)
# Targets Intel (x86_64) AND Apple Silicon (arm64); the right asset is picked
# at run time via pick_arch. No admin, no /tmp, stock /bin/bash 3.2 compatible.
# ============================================================

# Include guard: both entry scripts may end up sourcing this (and a future
# caller might source it twice). Make the second source a clean no-op so the
# helper definitions and $FAILED accumulator are never clobbered. `return`
# works only when sourced; if this file is ever executed, exit cleanly instead.
if [ -n "${_LIB_NO_BREW_SOURCED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
_LIB_NO_BREW_SOURCED=1

# Best-effort: keep going if one tool fails (no `set -e`), but catch unset vars
# and pipe failures. Stays compatible with stock macOS /bin/bash 3.2 — avoid
# empty-array expansion under `set -u` (3.2 errors on `"${arr[@]}"` when empty).
set -uo pipefail

BIN="$HOME/.local/bin"
mkdir -p "$BIN"

# Keep ALL temp work under $HOME — this user has no access to /tmp or /var.
export TMPDIR="$HOME/.cache/no-brew/tmp"
mkdir -p "$TMPDIR"

# GUI apps land here (.app -> ~/Applications, writable without admin).
APPS="$HOME/Applications"

# Tools that failed / need manual install (for the end-of-run summary). Guarded
# with :- so a re-source never resets an accumulated list.
FAILED="${FAILED:-}"

# ---- arch ---------------------------------------------------

# pick_arch <intel-value> <arm64-value> — echo the value matching this machine.
# The ONE place arch differs; every arch-specific URL/regex flows through it.
pick_arch() {
  case "$(uname -m)" in
    arm64) echo "$2" ;;
    *)     echo "$1" ;;
  esac
}

# ---- preflight ----------------------------------------------

# preflight — supported-arch gate. Run-once guarded so calling it from both
# scripts (or twice) is harmless. Allows x86_64 AND arm64; aborts on anything
# else. The caller-specific toolchain check is require_tools (below), kept
# separate so manual-tools.sh isn't forced to require python3 it doesn't use.
preflight() {
  [ -n "${_NB_PREFLIGHT_DONE:-}" ] && return 0
  _NB_PREFLIGHT_DONE=1
  case "$(uname -m)" in
    x86_64|arm64) : ;;
    *) echo "Supported arches: x86_64, arm64; detected $(uname -m). Aborting." >&2; exit 1 ;;
  esac
}

# require_tools <cmd>...  — abort with Xcode CLT guidance if any are missing.
# (git for antidote/fzf clones, python3 for git-filter-repo's runtime.) Fail
# early with clear guidance instead of dying at the first `git clone` halfway in.
require_tools() {
  local missing="" t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
  done
  if [ -n "$missing" ]; then
    echo "Missing required tool(s):$missing" >&2
    echo "These come from the Xcode Command Line Tools. Install them first with:" >&2
    echo "    xcode-select --install" >&2
    echo "(that installer may prompt for admin), then re-run this script." >&2
    exit 1
  fi
}

# ---- helpers ------------------------------------------------

# Print every browser_download_url from a repo's latest release. Retries to
# survive transient network drops. Well under GitHub's 60 req/hr anon limit.
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
# at ~/.local so packages land in ~/.local/bin (already on PATH). Idempotent: a
# rerun replaces ~/.local/node with the latest LTS. Arch-aware via pick_arch.
install_node() {
  local ver url tmp top nbin arch
  arch="$(pick_arch x64 arm64)"
  # Newest LTS from the dist index. Objects are sorted newest-first; the first
  # one whose "lts" is a quoted codename (not false) is the current LTS release.
  ver="$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null \
          | tr '}' '\n' | grep '"lts":"' | head -n1 \
          | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
  if [ -z "$ver" ]; then
    echo "  ! node/npm: could not resolve latest LTS (network?) — skipped"; FAILED="$FAILED node"; return 0
  fi
  url="https://nodejs.org/dist/${ver}/node-${ver}-darwin-${arch}.tar.gz"
  tmp="$(mktemp -d)"
  if ! curl -fsSL "$url" -o "$tmp/node.tar.gz"; then
    echo "  ! node/npm: download failed (no build for ${ver} ${arch}?) — skipped"; FAILED="$FAILED node"; rm -rf "$tmp"; return 0
  fi
  if ! tar -xzf "$tmp/node.tar.gz" -C "$tmp"; then
    echo "  ! node/npm: extract failed — skipped"; FAILED="$FAILED node"; rm -rf "$tmp"; return 0
  fi
  top="$(find "$tmp" -maxdepth 1 -type d -name "node-*-darwin-${arch}" | head -n1)"
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
  PATH="$nbin:$PATH" "$nbin/npm" config set prefix "$HOME/.local" >/dev/null 2>&1
  echo "  ✓ node ${ver} + npm/npx"
}

# install_sdkman — SDKMAN into ~/.sdkman (for `sdk`). The official installer
# hard-aborts on stock bash 3.2, but that gate is wrapped in `[ -n "$BASH_VERSION" ]`,
# so running the SAME official installer under zsh skips it. Best-effort.
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

# strip_sdkman_bash_profile — SDKMAN appends its init snippet to BOTH ~/.zshrc
# and ~/.bash_profile. This setup is zsh-only and nothing reads ~/.bash_profile,
# so remove SDKMAN's snippet back out of it, leaving the ~/.zshrc copy untouched.
# Best-effort and idempotent.
strip_sdkman_bash_profile() {
  local bp="$HOME/.bash_profile"
  [ -f "$bp" ] || return 0
  grep -q 'sdkman-init.sh' "$bp" 2>/dev/null || return 0   # nothing SDKMAN-ish -> leave it
  local tmp="$TMPDIR/bash_profile.nosdkman.$$"
  grep -v -e 'THIS MUST BE AT THE END OF THE FILE FOR SDKMAN' \
          -e 'export SDKMAN_DIR=' \
          -e 'sdkman-init.sh' "$bp" > "$tmp" 2>/dev/null
  [ "$?" -gt 1 ] && { rm -f "$tmp" 2>/dev/null; return 0; }  # grep error -> don't touch the file
  if grep -q '[^[:space:]]' "$tmp" 2>/dev/null; then
    mv "$tmp" "$bp" && echo "  ✓ removed SDKMAN snippet from ~/.bash_profile (unused in this zsh setup)"
  else
    rm -f "$tmp" "$bp" && echo "  ✓ removed SDKMAN-only ~/.bash_profile (unused in this zsh setup)"
  fi
  return 0
}

# scaffold_dotfiles — make sure ~/.zprofile and ~/.zshrc carry the brew-free base
# config. Simple append, guarded by a marker so a re-run never duplicates. We
# append ONLY the bits we own; uv/cargo/SDKMAN each append their own afterward.
scaffold_dotfiles() {
  if ! grep -q 'no-brew base config' "$HOME/.zprofile" 2>/dev/null; then
    cat >> "$HOME/.zprofile" <<'ZPROFILE'

# ---- no-brew base config (perfect-bottles.sh) ----
# ~/.local/bin = most tools; ~/.cargo/bin = gkit (its cargo-dist installer)
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
export DIRENV_LOG_FORMAT=""    # silence direnv's background log output
ZPROFILE
    echo "  ✓ updated ~/.zprofile"
  fi

  if ! grep -q 'no-brew base config' "$HOME/.zshrc" 2>/dev/null; then
    cat >> "$HOME/.zshrc" <<'ZSHRC'

# ---- no-brew base config (perfect-bottles.sh) ----

# ---- System ----
ulimit -n 4096            # prevent "too many open files"
setopt AUTO_CD            # cd by typing a folder name
chpwd() { ls -C; }        # clean newline + listing after each cd

# ---- Completions (must run before SDKMAN/plugins, which call compdef) ----
autoload -Uz compinit
compinit -i               # -i: ignore "insecure" fpath dirs instead of prompting

# ---- Zsh plugins (antidote, cloned to ~/.antidote) ----
source "$HOME/.antidote/antidote.zsh"
antidote load < ~/.zsh_plugins.txt

# ---- Prompt (starship) ----
eval "$(starship init zsh)"

# ---- fzf (installed to ~/.fzf) ----
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ---- direnv (installed by manual-tools.sh; guarded so this is a no-op if absent) ----
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
ZSHRC
    echo "  ✓ updated ~/.zshrc"
  fi
}

# ---- GUI app helpers (.app -> ~/Applications, no admin) ----

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
  # `yes |` auto-accepts any embedded license; -nobrowse hides it from Finder.
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

# install_tinytex — TinyTeX into ~/Library/TinyTeX via the official no-admin
# installer. (Excluded from the Intel path because its installer prompted for
# admin on stock Ventura; on arm64 it lands per-user without a prompt.)
# Best-effort. The ~/Library guard mirrors a real sandbox failure mode.
install_tinytex() {
  mkdir -p "$HOME/Library"
  if curl -fsSL https://yihui.org/tinytex/install-bin-unix.sh | sh; then
    echo "  ✓ tinytex (~/Library/TinyTeX)"
  else
    echo "  ! tinytex: installer failed — skipped"; FAILED="$FAILED tinytex"
  fi
  return 0
}

# install_awscli — AWS CLI v2 via the official universal .pkg, installed into the
# current user's home (no admin) with `-target CurrentUserHomeDirectory`, then
# symlinked onto PATH. Best-effort.
install_awscli() {
  local tmp pkg root
  tmp="$(mktemp -d)"; pkg="$tmp/AWSCLIV2.pkg"
  if ! curl -fsSL "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "$pkg"; then
    echo "  ! awscli: download failed — skipped"; FAILED="$FAILED awscli"; rm -rf "$tmp"; return 0
  fi
  if installer -pkg "$pkg" -target CurrentUserHomeDirectory >/dev/null 2>&1; then
    # The per-user install lands under ~/aws-cli; expose `aws`/`aws_completer`.
    root="$HOME/aws-cli"
    if [ -x "$root/aws" ]; then
      ln -sf "$root/aws" "$BIN/aws"
      ln -sf "$root/aws_completer" "$BIN/aws_completer" 2>/dev/null
    fi
    echo "  ✓ awscli (~/aws-cli)"
  else
    echo "  ! awscli: per-user pkg install failed — skipped"; FAILED="$FAILED awscli"
  fi
  rm -rf "$tmp"
  return 0
}

# install_r — the CRAN R build, installed WITHOUT admin. CRAN's .pkg is root-only
# (so `installer -target CurrentUserHomeDirectory` is refused, unlike awscli's)
# and the `R` launcher hardcodes R_HOME_DIR=/Library/Frameworks/R.framework/... ,
# so a no-admin install means: expand the pkg, lift R.framework into ~/.local,
# rewrite that baked-in R_HOME_DIR to the new path, and expose R/Rscript on PATH
# (~/.local/bin, already on PATH). Rscript is a compiled binary that reads no
# hardcoded home but honors $R_HOME, so it gets a tiny R_HOME-exporting wrapper.
# Arch-aware (Intel + Apple Silicon). Best-effort; idempotent (replaces in place).
install_r() {
  local slug asset base pkgfile url tmp fw dest rhome launcher
  slug="$(pick_arch big-sur-x86_64 big-sur-arm64)"
  asset="$(pick_arch x86_64 arm64)"
  base="https://cran.r-project.org/bin/macosx/${slug}/base"
  # Newest R-<ver>-<arch>.pkg from the CRAN dir listing (zero-pad the version so a
  # lexical sort is numeric, like install_docker_cli).
  pkgfile="$(curl -fsSL "$base/" 2>/dev/null \
              | grep -oE "R-[0-9]+\.[0-9]+\.[0-9]+-${asset}\.pkg" | sort -u \
              | awk -F'[-.]' '{printf "%05d%05d%05d %s\n",$2,$3,$4,$0}' | sort | tail -n1 | cut -d' ' -f2)"
  if [ -z "$pkgfile" ]; then
    echo "  ! R: could not resolve latest CRAN build (network?) — skipped"; FAILED="$FAILED R"; return 0
  fi
  url="$base/$pkgfile"
  tmp="$(mktemp -d)"
  if ! curl -fsSL "$url" -o "$tmp/R.pkg"; then
    echo "  ! R: download failed — skipped"; FAILED="$FAILED R"; rm -rf "$tmp"; return 0
  fi
  # --expand-full also extracts the component Payloads, so R.framework appears as
  # real files under $tmp/x (find is robust to the internal component naming).
  if ! pkgutil --expand-full "$tmp/R.pkg" "$tmp/x" >/dev/null 2>&1; then
    echo "  ! R: could not expand pkg — skipped"; FAILED="$FAILED R"; rm -rf "$tmp"; return 0
  fi
  fw="$(find "$tmp/x" -maxdepth 6 -type d -name 'R.framework' | head -n1 || true)"
  if [ -z "$fw" ]; then
    echo "  ! R: R.framework not found in pkg payload — skipped"; FAILED="$FAILED R"; rm -rf "$tmp"; return 0
  fi
  dest="$HOME/.local/R.framework"
  rm -rf "$dest"                       # re-run refreshes: replace any older copy
  if ! cp -R "$fw" "$dest"; then
    echo "  ! R: could not place framework in ~/.local — skipped"; FAILED="$FAILED R"; rm -rf "$tmp"; return 0
  fi
  rm -rf "$tmp"
  rhome="$dest/Resources"
  # Rewrite the launcher's hardcoded home so `R` (and everything it spawns) finds
  # its framework under $HOME instead of the non-existent /Library/Frameworks.
  launcher="$rhome/bin/R"
  if [ -f "$launcher" ]; then
    sed -i.bak "s#^R_HOME_DIR=.*#R_HOME_DIR=$rhome#" "$launcher" && rm -f "$launcher.bak"
  fi
  ln -sf "$launcher" "$BIN/R"
  # Rscript honors $R_HOME; give it a wrapper that points at the relocated tree.
  printf '#!/bin/sh\nexport R_HOME="%s"\nexec "%s/bin/Rscript" "$@"\n' "$rhome" "$rhome" > "$BIN/Rscript"
  chmod +x "$BIN/Rscript"
  echo "  ✓ R (~/.local/R.framework)"
  return 0
}

# ---- container dev (colima): prebuilt, no-admin -------------
# colima IS the container runtime (Docker engine in a Lima VM, vz backend — no
# Docker Desktop, no daemon to install). brew would source-build colima + lima +
# qemu + Go on a non-admin ~/brew prefix, so install prebuilt instead.

# install_lima — Lima (limactl, colima's engine) as a prebuilt tarball into
# ~/.local. The tarball ships bin/ + share/ which must stay siblings (limactl finds
# its guest agents at ../share/lima), so extract the whole thing into ~/.local.
install_lima() {
  local url tmp arch
  arch="$(pick_arch x86_64 aarch64)"
  url="$(release_urls lima-vm/lima | grep -iE "Darwin-${arch}\.tar\.gz\$" | head -n1 || true)"
  if [ -z "$url" ]; then
    echo "  ! lima: GitHub API gave no asset — skipped"; FAILED="$FAILED lima"; return 0
  fi
  tmp="$(mktemp -d)"
  if curl -fsSL "$url" -o "$tmp/lima.tar.gz" && tar -xzf "$tmp/lima.tar.gz" -C "$HOME/.local"; then
    echo "  ✓ lima (limactl)"
  else
    echo "  ! lima: download/extract failed — skipped"; FAILED="$FAILED lima"
  fi
  rm -rf "$tmp"
  return 0
}

# install_docker_cli — the Docker CLI *client* only (colima provides the engine).
# Static binary from download.docker.com (no GitHub API there; resolve the newest
# docker-<ver>.tgz by zero-padding the version so a plain lexical sort = numeric).
install_docker_cli() {
  local arch base file tmp
  arch="$(pick_arch x86_64 aarch64)"
  base="https://download.docker.com/mac/static/stable/$arch"
  file="$(curl -fsSL "$base/" 2>/dev/null \
            | grep -oE 'docker-[0-9]+\.[0-9]+\.[0-9]+\.tgz' | sort -u \
            | awk -F'[-.]' '{printf "%05d%05d%05d %s\n",$2,$3,$4,$0}' | sort | tail -n1 | cut -d' ' -f2)"
  if [ -z "$file" ]; then
    echo "  ! docker (cli): could not resolve latest static build — skipped"; FAILED="$FAILED docker"; return 0
  fi
  tmp="$(mktemp -d)"
  if curl -fsSL "$base/$file" -o "$tmp/d.tgz" && tar -xzf "$tmp/d.tgz" -C "$tmp" && [ -x "$tmp/docker/docker" ]; then
    install -m 0755 "$tmp/docker/docker" "$BIN/docker"     # just the client; colima is the engine
    echo "  ✓ docker (cli)"
  else
    echo "  ! docker (cli): download/extract failed — skipped"; FAILED="$FAILED docker"
  fi
  rm -rf "$tmp"
  return 0
}

# ---- summary ------------------------------------------------

# print_summary — PATH hint (if ~/.local/bin isn't on PATH yet) + the list of
# skipped / manual tools + a closing line. Each entry script calls this at its
# end; run one-by-one, each prints its own $FAILED for the tools it handled.
print_summary() {
  case ":$PATH:" in
    *":$BIN:"*) ;;
    *) echo "
Add this near the top of ~/.zprofile (gkit lives in ~/.cargo/bin):
  export PATH=\"\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH\"" ;;
  esac

  if [ -n "$FAILED" ]; then
    echo "
! Skipped or needs manual install:$FAILED
  Re-running this script is safe — installed tools refresh in place."
  fi

  echo "
Done. Open a new shell, then verify the tools you installed.
See the setup guide (docs/) for docker and the .zshrc changes."
}

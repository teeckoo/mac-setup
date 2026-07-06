#!/usr/bin/env bash
# ============================================================
# manual-tools.sh
# Installs the non-admin "install manually" list (coursier, direnv, bat, awscli,
# tinytex, R, + eza/wget/gnupg guidance) as PREBUILT binaries / no-admin installers —
# on BOTH the old Intel mac and the new Apple Silicon mac. Why both? A non-admin
# Homebrew lives in a custom prefix (~/brew), and Homebrew only ships bottles for
# the DEFAULT prefix — so `brew install` of these would build from source (slow) or
# fail. We grab the vendor's prebuilt binary instead. (Homebrew CASKS are prebuilt
# regardless of prefix, so GUI apps + the font come from `brew bundle` on Apple
# Silicon; on Intel there's no brew, so this script installs the GUI apps too.)
#
# Companion to perfect-bottles.sh (Intel CLI core). Admin users don't need either
# script — their default-prefix brew bottles everything. See the setup guide in docs/.
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

preflight                      # x86_64 or arm64; aborts otherwise

# ---- manual-list CLI tools (prebuilt; BOTH arches) ---------
# brew would source-build these in a non-admin ~/brew prefix, so install the
# vendor's prebuilt binary. pick_arch selects the x86_64 vs aarch64 asset.
echo "Installing manual-list CLI tools (prebuilt — avoids brew source builds) ..."
install_gzbin  "https://github.com/coursier/coursier/releases/latest/download/cs-$(pick_arch x86_64-apple-darwin aarch64-apple-darwin).gz" cs
install_rawbin "https://github.com/direnv/direnv/releases/latest/download/direnv.darwin-$(pick_arch amd64 arm64)" direnv
install_archive sharkdp/bat "$(pick_arch x86_64-apple-darwin aarch64-apple-darwin)\.tar\.gz" bat
install_awscli   # AWS CLI v2 universal pkg, per-user install (~/aws-cli), no admin

# tinytex: no brew formula at all. Its installer is no-admin on Apple Silicon; on
# stock Intel Ventura it prompted for an admin password, so guidance-only there.
case "$(uname -m)" in
  arm64) install_tinytex ;;
  *) echo "  - tinytex: skipped on Intel (installer prompts for admin on Ventura); install by hand from https://yihui.org/tinytex/ if you need LaTeX"; FAILED="$FAILED tinytex" ;;
esac

# mdbook: a clean prebuilt binary. On Intel perfect-bottles.sh installs it; on
# Apple Silicon that script doesn't run and a non-admin ~/brew would source-build
# it (Rust), so grab the vendor's prebuilt aarch64 binary here instead.
case "$(uname -m)" in
  arm64) install_archive rust-lang/mdBook 'aarch64-apple-darwin\.tar\.gz' mdbook ;;
esac

# R (CRAN): no non-admin brew path — the `r` cask prompts for admin and a
# non-admin ~/brew would source-build. Install the official CRAN build without
# admin by relocating its framework into ~/.local (see install_r). Both arches.
install_r

# eza/wget/gnupg: no clean no-admin macOS install on either arch -> guidance.
echo "  - eza:   no macOS binary on any arch; use 'ls' / 'ls -R', or 'cargo install eza'"; FAILED="$FAILED eza"
echo "  - wget:  no static no-admin macOS binary; use 'curl', or build from source"; FAILED="$FAILED wget"
echo "  - gnupg: no clean no-admin path; use SSH commit signing if GPG was only for signed commits"; FAILED="$FAILED gnupg"

# ---- container dev: colima (prebuilt; both arches) ---------
# colima provides the Docker engine (Lima VM, vz backend — no admin, no Docker
# Desktop). We install the prebuilt colima + lima + the docker CLI *client*.
echo "Installing colima container runtime (prebuilt — avoids brew source builds) ..."
install_lima
install_rawbin "https://github.com/abiosoft/colima/releases/latest/download/colima-Darwin-$(pick_arch x86_64 arm64)" colima
install_docker_cli
echo "  -> start it with:  colima start --vm-type vz   (no admin), then 'docker …' works"

# ---- GUI apps ----------------------------------------------
# Intel has no brew, so install the GUI apps here (copy into ~/Applications, no
# admin). On Apple Silicon, `brew bundle` installs them as casks (prebuilt, into
# ~/Applications via HOMEBREW_CASK_OPTS=--appdir, no admin) — so skip here.
case "$(uname -m)" in
  x86_64)
    echo "Installing GUI apps into $APPS (no admin) ..."
    mkdir -p "$APPS"; chmod 700 "$APPS"
    install_appzip "https://iterm2.com/downloads/stable/latest"                                 iTerm2
    install_appzip "https://update.code.visualstudio.com/latest/darwin/stable"                  "VS Code"
    install_dmg    "https://download.jetbrains.com/product?code=IIU&latest&distribution=mac"    "IntelliJ IDEA"
    install_dmg    "https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg"    "Google Chrome"
    install_dmg    "https://download.mozilla.org/?product=firefox-latest-ssl&os=osx&lang=en-US" Firefox
    install_dmg    "https://slack.com/ssb/download-osx"                                         Slack
    BRUNO_URL="$(release_urls usebruno/bruno | grep -iE 'x64_mac\.dmg$' | head -n1 || true)"
    if [ -n "$BRUNO_URL" ]; then
      install_dmg "$BRUNO_URL" Bruno
    else
      echo "  ! Bruno: GitHub API gave no asset (rate limit or network?) — skipped"; FAILED="$FAILED Bruno"
    fi
    ;;
  arm64)
    echo "  - GUI apps (iTerm2, VS Code, IntelliJ, Chrome, Firefox, Bruno, Slack) + font: from 'brew bundle' casks (--appdir=~/Applications, no admin)."
    ;;
esac

print_summary

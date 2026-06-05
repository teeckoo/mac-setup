# Setup without Homebrew (Intel Mac, non-admin)

For machines where Homebrew isn't usable (old/unsupported macOS, no admin, or
brew only builds slowly from source). Everything below installs into your home
directory — **no admin rights needed**.

Target tested: MacBook Pro 2017, Intel `x86_64`, macOS Ventura 13.

## 1. Run the installer

```sh
curl -fsSL -o install-no-brew.sh \
  https://raw.githubusercontent.com/teeckoo/mac-setup/main/install-no-brew.sh
bash install-no-brew.sh
rm install-no-brew.sh
```

Installs into `~/.local/bin` (static binaries) and via official installers:
`gkit`, `ripgrep` (rg), `gum`, `glow`, `pandoc`, `jq`, `bat`, `direnv`,
`coursier` (cs), `git-filter-repo`, `uv`, `starship`, `claude` (Claude Code),
`node` + `npm`/`npx`, plus `antidote` and `fzf` for zsh. It also installs
**SDKMAN** (`sdk`) into `~/.sdkman` for JVM/Java version management (see §5). It also installs the **GUI apps** into
`~/Applications` and the **FiraCode Nerd Font** into `~/Library/Fonts`
(see section 3). It resolves each tool's **latest** release automatically, so
there are no pinned versions to update.

> The GUI apps add ~2 GB of downloads to the run. They're folded into the same
> script (no admin needed — `~/Applications` is user-writable), so a single run
> sets up CLI tools and apps together.

> **No `sdkman` on stock macOS.** Its installer hard-requires Bash 4+, but macOS
> ships only Bash 3.2 and we can't brew a newer one. For JDK/JVM version
> management without brew, use the already-installed **coursier**: `cs java --setup`.

> **Not included on Intel: `fd`, `eza`, `delta`.** Their current upstream
> releases no longer publish an Intel (`x86_64`) macOS binary (eza ships none at
> all; fd and delta ship Apple-Silicon-only). Rather than pin to stale versions,
> they're left out. Use the built-ins instead: `rg`/`find` for fd, `ls` for eza,
> and git's default pager for delta. If you move to an Apple Silicon Mac, they
> can be added back.

> Note: `coursier`, `direnv`, and `bat` were flagged in `softwares.md` as
> slow/failing under brew (brew compiled them from source). Without brew they
> install as **prebuilt binaries**, so they're now fast and need no admin.

> **Node / npm.** The official Node.js **LTS** Intel tarball is unpacked into
> `~/.local/node` (no admin) with `node`, `npm`, and `npx` symlinked onto your
> PATH. Global installs are redirected to `~/.local` (`npm config set prefix`),
> so `npm i -g <pkg>` lands in `~/.local/bin` — already on PATH — instead of
> failing on a permission-denied write to `/usr/local`. A rerun replaces
> `~/.local/node` with the latest LTS. If your existing `~/.npmrc` already sets a
> `prefix`, this overwrites it.

> **TinyTeX removed.** On this stock macOS its installer triggered an admin-password
> prompt, which breaks the no-admin guarantee, so it's no longer installed. If you
> need LaTeX, install it manually from <https://yihui.org/tinytex/> and verify your
> environment doesn't prompt for admin.

> macOS Gatekeeper may quarantine a downloaded binary on first run
> ("cannot be opened"). Clear it with:
> `xattr -dr com.apple.quarantine ~/.local/bin`

### Re-running the installer

The script is **safe to re-run any time** — to finish a partial install (e.g. a
download that hit a network drop or a GitHub rate-limit), or to update everything
to the latest. It's idempotent; there are no pinned versions, so each run lands
on the newest builds. What happens to things already on disk:

- **Most tools are refreshed in place.** Every CLI binary (`rg`, `gum`, `glow`,
  `pandoc`, `bat`, `jq`, `direnv`, `cs`, `git-filter-repo`) and every vendor
  installer (`gkit`, `uv`, `starship`, `claude`) re-resolves the latest version
  and overwrites the existing copy — no duplicates, no "already installed" skip.
- **Node is replaced with the latest LTS.** `~/.local/node` is wiped and
  reinstalled. Your globally-installed npm packages survive (they live in
  `~/.local`, not `~/.local/node`). After a *major* LTS bump, global packages
  with native bindings may need a `npm i -g` reinstall to match the new ABI.
- **`antidote` and `fzf` are left untouched** if already present (a directory
  check guards them) — they are **not** re-cloned or updated. Delete `~/.antidote`
  / `~/.fzf` first if you want them refreshed.
- **A tool that can't reach its source keeps its current copy.** On a rate-limit
  or network failure the script logs it, adds it to the end-of-run skipped list,
  and moves on *without* removing what's already installed. Re-run later to retry
  only those.
- **GUI apps are replaced in place** with the latest build; a failed download
  leaves the existing `.app` untouched.

> A re-run **re-downloads** everything it refreshes (there's no local cache), so
> expect the full bandwidth again (~200 MB for Node, ~2 GB for the GUI apps).
> Only `antidote`/`fzf` and unreachable tools are genuinely skipped.

## 2. Shell config — brew-free version

The main README sources tools via `$(brew --prefix)`, which doesn't exist here.
Use the split below: environment/PATH in `~/.zprofile` (runs once at login),
interactive setup in `~/.zshrc`. On macOS every Terminal/iTerm tab is a login
shell, so `~/.zprofile` reliably sets your PATH.

`~/.zprofile`

```zsh
# ============================================================
# ~/.zprofile — login shell. Environment & PATH.
# ============================================================

# Binaries installed by install-no-brew.sh
# (~/.local/bin = most tools; ~/.cargo/bin = gkit, via its cargo-dist installer)
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Silence direnv's background log output (keeps the prompt clean)
export DIRENV_LOG_FORMAT=""
```

`~/.zshrc`

```zsh
# ============================================================
# ~/.zshrc — every interactive shell.
# ============================================================

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

# ---- direnv ----
eval "$(direnv hook zsh)"
```

> **Don't add a SDKMAN block to `~/.zshrc` yourself.** SDKMAN's own installer
> appends its init snippet (`export SDKMAN_DIR=…` + the `sdkman-init.sh` source)
> to the **end** of `~/.zshrc` automatically when `install-no-brew.sh` runs it.
> That snippet has to be the last thing in the file — which is exactly where it
> lands — and it's idempotent, so a re-run won't add a second copy. `~/.zprofile`
> needs nothing for SDKMAN.
>
> SDKMAN also writes the same snippet into `~/.bash_profile`, but nothing reads
> that file in this zsh-only setup (your login shell is zsh, and direnv sources
> `sdkman-init.sh` directly), so `install-no-brew.sh` strips it back out — leaving
> only the `~/.zshrc` copy.
>
> Not needed for the direnv `.envrc` case — there you `source` `sdkman-init.sh`
> inside the `.envrc` itself (see §5), which runs independently of `~/.zshrc`.

> **Why the `compinit -i`.** `sdkman-init.sh` (and zsh completion generally) calls
> `compinit`, which refuses to run if any `fpath` directory is "insecure" — i.e.
> owned by someone other than you or root. On a machine that once had Homebrew,
> `/usr/local/share/zsh/site-functions` is left behind owned by the old admin
> user; you can't `chmod` it without admin, so a bare `compinit` prompts at every
> new shell (and, if aborted, leaves `compdef` undefined → `command not found:
> compdef`). Running `compinit -i` early — before anything sources
> `sdkman-init.sh` — ignores those dirs silently and defines `compdef`, so SDKMAN
> skips its own `compinit`. Keep it above the plugin and SDKMAN lines.

`~/.zsh_plugins.txt` — the antidote plugin list. `install-no-brew.sh` creates it
for you (with the two lines below) if it's missing; edit it to add plugins:

```
zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
```

## 3. GUI apps (casks) — installed automatically

`install-no-brew.sh` now installs these into `~/Applications` for you (no admin
needed). It downloads the vendor `.dmg`/`.zip`, copies the `.app` out, and clears
the Gatekeeper quarantine flag so each opens on first launch. All are the latest
Intel/universal builds, resolved at run time:

| App | Source |
| --- | --- |
| iTerm2 | `iterm2.com/downloads/stable/latest` (zip, universal) |
| VS Code | `update.code.visualstudio.com/latest/darwin/stable` (Intel) |
| IntelliJ IDEA | `download.jetbrains.com/product?code=IIU&latest&distribution=mac` |
| Google Chrome | `dl.google.com/.../googlechrome.dmg` (universal) |
| Firefox | `download.mozilla.org/?product=firefox-latest-ssl&os=osx` |
| Slack | `slack.com/ssb/download-osx` (Intel x64) |
| Bruno | latest GitHub release, `*_x64_mac.dmg` |

It also installs **FiraCode Nerd Font** (required by starship) into
`~/Library/Fonts`.

> If any app's download fails (network/rate limit), the script logs it and keeps
> going — just re-run to retry; existing apps are replaced in place.

> **Not automated: Opera and Chromium.** Neither offers a clean, signed,
> scriptable Intel download (Chromium ships only unsigned snapshots). Install
> them by hand if needed: Opera <https://www.opera.com/download>, Chromium
> <https://download-chromium.appspot.com/>.

## 4. Tools needing manual handling

- **awscli** — official installer, into your home dir (no admin):
  ```sh
  curl -o AWSCLIV2.pkg https://awscli.amazonaws.com/AWSCLIV2.pkg
  installer -pkg AWSCLIV2.pkg -target CurrentUserHomeDirectory
  rm AWSCLIV2.pkg
  # adds ~/aws-cli; symlink it onto PATH:
  ln -sf "$HOME/aws-cli/aws" "$HOME/.local/bin/aws"
  ```
- **docker + colima** — needs a Linux VM (lima + QEMU). Heavy and awkward
  without admin on this hardware; recommend Docker Desktop or a remote/CI
  docker host instead, or skip if not needed.
- **wget** — no official static mac binary. macOS ships `curl`; use that, or
  build wget from source with Xcode CLT + OpenSSL (slow — same problem brew had).
- **gnupg** — no clean no-admin path. Either install GPG Suite
  (https://gpgtools.org — `.pkg`, needs admin) or build from source. If you only
  need signed git commits, consider SSH-key commit signing instead (no GPG).
- **tree** — no Intel prebuilt; use `find . -type d` or `ls -R` instead.
- **gnu-sed** — no prebuilt mac binary; install via `uv`/pip
  (`uv tool install ...`) is not available. If you need GNU sed specifically,
  build from source with Xcode Command Line Tools; otherwise BSD `sed` ships
  with macOS.

## 5. SDKMAN — `sdk` (installed automatically)

`install-no-brew.sh` installs **SDKMAN** into `~/.sdkman` (no admin) and wires up
`~/.zshrc`, so `sdk` is ready in a new shell. Use it to manage JDK/JVM versions:

```sh
source "$HOME/.sdkman/bin/sdkman-init.sh"   # or just open a new shell
sdk list java                               # see versions
sdk install java 21.0.5-tem
```

If your projects pin Java with `sdk` in a direnv `.envrc`, that keeps working —
direnv evaluates `.envrc` in bash, and SDKMAN's `sdkman-init.sh` is
bash-3.2-safe:

```sh
# .envrc
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk use java 21.0.5-tem
```

> **Why it installs cleanly here.** SDKMAN's official installer hard-aborts on
> stock macOS bash 3.2 (`SDKMAN requires Bash 4 or higher`). That check only runs
> under bash, so the installer runs the **unmodified** official installer under
> **zsh**, where the gate is skipped (the parent `install-no-brew.sh` stays bash;
> only this sub-installer is piped to zsh — same idea as the `claude` line being
> piped to bash). SDKMAN's runtime has no bash-4 features, so `sdk` works in zsh
> *and* the bash direnv uses. If SDKMAN's download is ever unreachable, the run
> logs it and continues — the rest of the setup is unaffected.

> Just need a JDK (no SDKMAN)? The already-installed **coursier** also does it
> with no setup: `cs java --setup` (or `cs java --jvm 21 --setup`).

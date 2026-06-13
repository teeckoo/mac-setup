## Troubleshooting

**Gatekeeper "cannot be opened".** macOS may quarantine a downloaded binary on first
run. Clear it:

```sh
xattr -dr com.apple.quarantine ~/.local/bin
```

**`compinit` prompts every shell / `command not found: compdef`.** A leftover Homebrew
`site-functions` dir owned by the old admin makes a bare `compinit` refuse to run. The
`~/.zshrc` block uses `compinit -i` (ignore insecure dirs) **before** the plugin/SDKMAN
lines — keep that order.

**`npm i -g` permission denied.** Global installs are redirected to `~/.local`
(`npm config set prefix ~/.local`), so packages land in `~/.local/bin` (already on
PATH). After a major Node LTS bump, packages with native bindings may need a
`npm i -g` reinstall to match the new ABI.

## Re-running is safe (idempotent)

Both `perfect-bottles.sh` and `manual-tools.sh` re-run safely — to finish a partial
install or refresh to latest. CLI binaries and vendor installers overwrite in place
(no duplicates); Node wipes/reinstalls latest LTS (global packages survive); GUI apps
are replaced in place (a failed download leaves the old `.app`); `antidote`/`fzf` are
left alone if present; an unreachable source keeps its existing copy and is logged.
There's no local cache, so a refresh re-downloads (~200 MB Node, ~2 GB GUI apps).

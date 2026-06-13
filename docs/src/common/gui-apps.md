## GUI apps (no admin password)

`manual-tools.sh` installs these into `~/Applications` by copying the `.app` out of
the vendor `.dmg`/`.zip` and clearing the Gatekeeper quarantine flag — **no `sudo`,
no admin prompt** (unlike brew casks, which install to `/Applications` and ask for an
admin password):

| App | Source | Arch |
| --- | --- | --- |
| iTerm2 | `iterm2.com/downloads/stable/latest` | universal |
| VS Code | `update.code.visualstudio.com/latest/<darwin\|darwin-arm64>/stable` | per-arch |
| IntelliJ IDEA | `download.jetbrains.com/product?code=IIU&latest&distribution=<mac\|macM1>` | per-arch |
| Google Chrome | `dl.google.com/.../googlechrome.dmg` | universal |
| Firefox | `download.mozilla.org/?product=firefox-latest-ssl&os=osx` | universal |
| Bruno | latest GitHub release, `*_<x64_mac\|arm64_mac>.dmg` | per-arch |
| Slack | `slack.com/ssb/download-osx` | universal |

A failed download is logged and skipped — re-run to retry; existing apps are replaced
in place. (Opera and Chromium aren't automated — no clean signed download; grab them by
hand if needed.)

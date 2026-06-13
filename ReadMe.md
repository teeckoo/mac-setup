# mac-setup

**📖 Setup guide → <https://teeckoo.github.io/mac-setup/>**

Pick your path in the guide:

- **Non-admin · new Mac (Apple Silicon)** — Homebrew for CLI tools + `manual-tools.sh` for no-admin GUI apps.
- **Non-admin · old Intel (no Homebrew)** — `perfect-bottles.sh` + `manual-tools.sh`, no admin.
- **Admin · new Mac** — `brew bundle` does everything.

The guide is built with [mdBook](https://rust-lang.github.io/mdBook/) from
[`docs/`](docs/) (run `mdbook serve docs` to preview locally). The brew package list
is the [`Brewfile`](Brewfile).

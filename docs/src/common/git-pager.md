## git log pager

Keep `git log` on one screen (git ships with the Xcode Command Line Tools):

```sh
git config --global --replace-all core.pager "less -F -X"
```

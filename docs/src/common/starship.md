## starship prompt

Create `~/.config/starship.toml`:

```toml
format = """
$directory $git_branch$git_status$all
$character"""

[line_break]
disabled = false

[directory]
truncation_length = 0
truncate_to_repo = false
```

(starship reads this automatically; the `~/.zshrc` block below runs `starship init zsh`.)

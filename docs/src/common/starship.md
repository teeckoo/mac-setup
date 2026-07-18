## starship prompt

Create `~/.config/starship.toml`:

```toml
format = """
${env_var.OPTIONAL_PROMPT_HEADER}\
$directory $git_branch$git_status$all${env_var.OPTIONAL_PROMPT_FOOTER}
$character"""

[line_break]
disabled = false

[directory]
truncation_length = 0
truncate_to_repo = false

[env_var.OPTIONAL_PROMPT_HEADER]
variable = "OPTIONAL_PROMPT_HEADER"
# The \n is placed inside the string format so it only triggers if text exists
format = "[$env_value]($style)\n"
style = "bold blue"

[env_var.OPTIONAL_PROMPT_FOOTER]
variable = "OPTIONAL_PROMPT_FOOTER"
format = "[$env_value]($style)\n" # Newline at the START
style = "bold yellow"

```

(starship reads this automatically; the `~/.zshrc` block below runs `starship init zsh`.)

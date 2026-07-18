## global direnv to add support for source_up_sdkmanrc

Create `~/.config/direnv/direnvrc`:

```
# ==============================================================================
# 1. Fully Generic SDKMAN! Environment Loader (Local Folder Scope)
# ==============================================================================
layout_sdkman() {
  : "${SDKMAN_DIR:=$HOME/.sdkman}"
  
  if [[ -f ".sdkmanrc" && -f "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    local zsh_safeguards='export ZSH_DISABLE_COMPFIX="true"; autoload -U compinit; compinit -u;'
    direnv_load "$SHELL" -c "$zsh_safeguards source '$SDKMAN_DIR/bin/sdkman-init.sh' && sdk env >/dev/null 2>&1 && direnv dump"
  fi
}

# ==============================================================================
# 2. Agnostic Ancestor Discovery Hook (Strict Explicit Execution)
# ==============================================================================
source_up_sdkmanrc() {
  : "${SDKMAN_DIR:=$HOME/.sdkman}"
  
  # Start hunting from the parent folder upward
  local current_dir
  current_dir=$(dirname "$PWD")
  
  # Climb all the way to the filesystem root (/) until a file is found
  while [[ "$current_dir" != "/" ]]; do
    if [[ -f "$current_dir/.sdkmanrc" ]]; then
      if [[ -f "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
        
        # Explicit Logging: Always print because this line is explicitly uncommented here
        echo "direnv: loading $current_dir/.sdkmanrc" >&2

        # Force evaluation inside that specific directory layer using an isolated subshell
        local zsh_safeguards='export ZSH_DISABLE_COMPFIX="true"; autoload -U compinit; compinit -u;'
        direnv_load "$SHELL" -c "cd '$current_dir' && $zsh_safeguards source '$SDKMAN_DIR/bin/sdkman-init.sh' && sdk env >/dev/null 2>&1 && direnv dump"
        
        # Mark that the local context explicitly requested and applied an SDK toolchain
        _LOCAL_SDKMAN_APPLIED="true"
      fi
      return 0
    fi
    current_dir=$(dirname "$current_dir")
  done
}

# ==============================================================================
# 3. Safe Global Overwrite: Protect Child Contexts During Tree Traversal
# ==============================================================================
source_up() {
  # 1. Take a clean snapshot of all environment variables BEFORE climbing the tree
  local env_snapshot
  env_snapshot=$(env | grep -v '^DIRENV_' | grep -v '^direnv_')

  # 2. Find and execute the parent configuration natively without relying on 'source_up' function hooks
  local parent_envrc
  parent_envrc=$(find_up .envrc)
  if [[ -n "$parent_envrc" && "$parent_envrc" != "$PWD/.envrc" ]]; then
    source_env "$parent_envrc"
  fi

  # 3. THE USER PERSPECTIVE ISOLATION ENFORCEMENT:
  #    If 'source_up_sdkmanrc' is NOT explicitly uncommented and executed in this folder,
  #    we restore the toolchain variables back to your original baseline shell state.
  if [[ "$_LOCAL_SDKMAN_APPLIED" != "true" && ! -f ".sdkmanrc" ]]; then
    while read -r line; do
      if [[ "$line" == *=* ]]; then
        local key="${line%%=*}"
        local val="${line#*=}"
        # If a variable ends with _HOME or was modified by SDKMAN, revert it
        if [[ "$key" == *_HOME ]] || [[ "$key" == sdkman_* ]]; then
          export "$key"="$val"
        fi
      fi
    done <<< "$env_snapshot"

    # Also wipe out any new software candidates added to the path by parent folders
    PATH_rm "$SDKMAN_DIR/candidates/*/*" 2>/dev/null
    PATH_rm "$HOME/.sdkman/candidates/*/*" 2>/dev/null
  fi
}

# ==============================================================================
# 4. Automated Local Tool Placement Trigger
# ==============================================================================
auto_load_local_tools() {
  if [[ -f ".sdkmanrc" ]]; then
    layout_sdkman
  fi
}
auto_load_local_tools
```

# Roadmap: Fish Shell Migration

**Milestone:** v1.0 Working Baseline
**Created:** 2025-02-05
**Phases:** 4

## Overview

| # | Phase | Goal | Requirements | Status |
|---|-------|------|--------------|--------|
| 1 | Config Structure | Create fish config files in chezmoi | CONF-01, CONF-02 | ○ Pending |
| 2 | Environment & Secrets | Set up PATH, variables, 1Password | ENV-01-04, SEC-01-03 | ○ Pending |
| 3 | Tool Integrations | Initialize shell tools | TOOL-01-05 | ○ Pending |
| 4 | Abbreviations | Convert aliases to abbreviations | ABBR-01-06 | ○ Pending |

---

## Phase 1: Config Structure

**Goal:** Create the fish configuration file structure within chezmoi

**Requirements:** CONF-01, CONF-02

**Success Criteria:**
1. `dot_config/private_fish/` directory exists in chezmoi
2. `config.fish.tmpl` created with basic structure and chezmoi templating
3. `chezmoi apply` successfully creates `~/.config/fish/config.fish`
4. Fish shell starts without errors

**Notes:**
- Use `private_fish` prefix so chezmoi sets correct permissions
- Template must include chezmoi header for secrets processing

---

## Phase 2: Environment & Secrets

**Goal:** Configure PATH, environment variables, and 1Password integration

**Requirements:** ENV-01, ENV-02, ENV-03, ENV-04, SEC-01, SEC-02, SEC-03

**Success Criteria:**
1. `echo $PATH` includes ~/.local/bin, ~/.bin, cargo, go paths
2. `echo $EDITOR` returns "vi"
3. Homebrew paths present on macOS, linuxbrew on Linux
4. `echo $SSH_AUTH_SOCK` points to correct 1Password socket
5. Chezmoi-templated secrets (Cloudflare, OpenWeather) populated

**Notes:**
- Fish syntax: `set -gx VAR value` (not `export`)
- OS detection: use chezmoi `{{ if eq .chezmoi.os "darwin" }}`
- Fish also has `set -gxp` to prepend to PATH

---

## Phase 3: Tool Integrations

**Goal:** Initialize shell tools (starship, atuin, mise, fzf, direnv)

**Requirements:** TOOL-01, TOOL-02, TOOL-03, TOOL-04, TOOL-05

**Success Criteria:**
1. Starship prompt displays correctly
2. `atuin` history search works (Ctrl+R or up arrow)
3. `mise` manages tool versions (`mise current` works)
4. fzf keybindings functional (Ctrl+T for files, Ctrl+R if not atuin)
5. direnv auto-loads `.envrc` files

**Notes:**
- Starship: `starship init fish | source`
- Atuin: `atuin init fish | source`
- Mise: `mise activate fish | source`
- fzf: source fzf fish bindings
- direnv: `direnv hook fish | source`

---

## Phase 4: Abbreviations

**Goal:** Convert zsh aliases to fish abbreviations

**Requirements:** ABBR-01, ABBR-02, ABBR-03, ABBR-04, ABBR-05, ABBR-06

**Success Criteria:**
1. Typing `vim` expands to `nvim` in command line
2. Git abbreviations work (gst → git status, etc.)
3. `la` expands to eza command with flags
4. `lg` expands to lazygit, `ld` to lazydocker
5. OS-specific abbreviations load only on correct OS
6. `cat` expands to `bat`

**Notes:**
- Fish abbreviations: `abbr -a gst git status`
- Abbreviations expand as you type (visible in history as full command)
- Can also use `alias` for things that shouldn't expand visibly
- OS-specific: wrap in chezmoi conditionals

---

## Dependencies

```
Phase 1 ──► Phase 2 ──► Phase 3 ──► Phase 4
(structure)  (env)       (tools)     (abbr)
```

All phases are sequential - each builds on the previous.

---
*Roadmap created: 2025-02-05*

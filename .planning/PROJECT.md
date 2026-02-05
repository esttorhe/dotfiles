# Fish Shell Migration

## What This Is

Fish shell configuration managed by chezmoi, migrated from zsh. Provides complete shell environment with abbreviations, tool integrations, 1Password secrets, and OS-specific handling for macOS and Linux.

## Core Value

A working fish shell configuration that preserves zsh functionality with fish-native patterns.

## Current State (v1.0 Shipped)

**Shipped:** 2025-02-05
**Config:** 275 lines of fish configuration
**Location:** `dot_config/private_fish/config.fish.tmpl`

**What's working:**
- 29 abbreviations (editor, git, tools, docker, chezmoi, OS-specific)
- Environment variables and PATH (OS-aware)
- Tool integrations (starship, atuin, mise, fzf, direnv)
- 1Password SSH agent and chezmoi-templated secrets
- Custom functions (obsidian, make-commands-habits)
- Fortune on shell start, Ctrl+L keybinding

## Requirements

### Validated

- CONF-01: Fish config structure — v1.0
- CONF-02: config.fish.tmpl entry point — v1.0
- ENV-01 through ENV-04: Environment and PATH — v1.0
- SEC-01 through SEC-03: 1Password and secrets — v1.0
- TOOL-01 through TOOL-05: Shell tool integrations — v1.0
- ABBR-01 through ABBR-06: Abbreviations — v1.0

### Active (v2 Candidates)

- [ ] FUNC-01: transfer() function for transfer.sh
- [ ] FUNC-02: sbr() function for git branch switching with fzf
- [ ] FUNC-03: brew.info function (macOS)
- [ ] FUNC-04: mount_remote_file function
- [ ] POLISH-01: Vi mode keybindings

### Out of Scope

| Feature | Reason |
|---------|--------|
| zsh plugin migration | Start clean, add fish plugins as needed |
| oh-my-zsh/antidote | Fish has different plugin ecosystem |
| Powerlevel10k config | Using Starship (cross-shell) |

## Context

- Fish branch tested and working
- Ctrl+L fortune has limitation (requires enter for prompt) — fish vs zsh difference
- User comfortable with fish after v1.0 testing

## Constraints

- **Templating**: Must use `.tmpl` extension for chezmoi secrets
- **Branch**: Work done on `fish` branch
- **Compatibility**: macOS (primary) and Linux (Arch, Debian)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Abbreviations over aliases | Fish-native, shows real command in history | Good |
| Drop plugins initially | Start clean, add back as needed | Good |
| `fish_add_path -g` for PATH | Cleaner than manual manipulation | Good |
| `type -q` for tool checks | Graceful fallback if tool missing | Good |
| Defer complex functions to v2 | Ship working baseline first | Good |

---
*Last updated: 2025-02-05 after v1.0 milestone*

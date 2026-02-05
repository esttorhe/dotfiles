# Fish Shell Migration

## What This Is

Migration of existing zsh configuration to fish shell within a chezmoi-managed dotfiles repository. The migration happens on a separate `fish` branch to allow testing before full commitment.

## Core Value

A working fish shell configuration that preserves the functionality of the existing zsh setup - aliases (as abbreviations), PATH, tool integrations, and secrets.

## Current Milestone: v1.0 Working Baseline

**Goal:** Functional fish configuration that covers core daily usage

**Target features:**
- config.fish.tmpl with chezmoi templating for secrets
- Abbreviations for all existing aliases
- PATH setup (OS-aware: macOS/Linux)
- Tool initializations (atuin, mise, starship, fzf)
- 1Password SSH agent socket configured

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Fish config structure created (`dot_config/fish/`)
- [ ] config.fish.tmpl with chezmoi templating
- [ ] Abbreviations converted from zsh aliases
- [ ] PATH variables set up (OS-specific)
- [ ] Tool integrations: atuin, mise, starship, fzf
- [ ] 1Password SSH_AUTH_SOCK configured
- [ ] Environment variables migrated
- [ ] OS-specific conditionals (macOS vs Linux)

### Out of Scope

- zsh plugin equivalents — add back individually as needed
- vi mode keybindings — polish later
- Custom functions (transfer, sbr, etc.) — phase 2
- Fortune/habits integration — nice-to-have later

## Context

- User is new to fish shell
- Using chezmoi for dotfiles management with 1Password integration
- Branch `fish` exists for safe testing
- Starship prompt already works with fish (no change needed)
- Most tools (atuin, mise, fzf) have native fish support

## Constraints

- **Templating**: Must use `.tmpl` extension for chezmoi to process secrets
- **Branch**: All work on `fish` branch, not `main`
- **Compatibility**: macOS (primary) and Linux (Arch, Debian) support

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Abbreviations over aliases | Fish-native, shows real command in history | — Pending |
| Drop plugins initially | Start clean, add back as needed | — Pending |

---
*Last updated: 2025-02-05 after project initialization*

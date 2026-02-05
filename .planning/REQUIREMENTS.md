# Requirements: Fish Shell Migration

**Defined:** 2025-02-05
**Core Value:** Working fish config preserving zsh functionality

## v1 Requirements

Requirements for working baseline. Each maps to roadmap phases.

### Config Structure

- [ ] **CONF-01**: Create `dot_config/private_fish/` directory structure for chezmoi
- [ ] **CONF-02**: Create `config.fish.tmpl` as main entry point

### Abbreviations

- [ ] **ABBR-01**: Core editor abbreviations (vim, vi → nvim)
- [ ] **ABBR-02**: Git abbreviations (gst, ga, gb, gp, gco, gd, etc.)
- [ ] **ABBR-03**: Tool abbreviations (la → eza, cat → bat, lg → lazygit, ld → lazydocker)
- [ ] **ABBR-04**: OS-specific abbreviations (update, rm → trash on macOS)
- [ ] **ABBR-05**: Docker abbreviations (dls, drm)
- [ ] **ABBR-06**: Chezmoi abbreviations (chema, cmm)

### Environment

- [ ] **ENV-01**: PATH setup (~/.local/bin, ~/.bin, cargo, go, etc.)
- [ ] **ENV-02**: Core variables (EDITOR, LANG, LC_ALL, TERM)
- [ ] **ENV-03**: OS-specific PATH additions (homebrew on macOS, linuxbrew on Linux)
- [ ] **ENV-04**: Tool-specific variables (GOPATH, PYENV_ROOT, ANDROID_HOME, etc.)

### Tool Integrations

- [ ] **TOOL-01**: Starship prompt init
- [ ] **TOOL-02**: Atuin history init
- [ ] **TOOL-03**: Mise version manager init
- [ ] **TOOL-04**: fzf integration
- [ ] **TOOL-05**: direnv hook

### Secrets

- [ ] **SEC-01**: 1Password SSH_AUTH_SOCK (OS-specific paths)
- [ ] **SEC-02**: Cloudflare headers via chezmoi/1Password
- [ ] **SEC-03**: OpenWeather API key via chezmoi/1Password

## v2 Requirements

Deferred to future. Add back as needed.

### Custom Functions

- **FUNC-01**: transfer() function for transfer.sh
- **FUNC-02**: sbr() function for git branch switching with fzf
- **FUNC-03**: brew.info function (macOS)
- **FUNC-04**: mount_remote_file function

### Polish

- **POLISH-01**: Vi mode keybindings
- **POLISH-02**: Fortune/habits integration on shell start
- **POLISH-03**: Custom clear with fortune (Ctrl+L)
- **POLISH-04**: Claude-telegram bridge aliases

## Out of Scope

| Feature | Reason |
|---------|--------|
| zsh plugin migration | Start clean, add fish plugins as needed |
| oh-my-zsh/antidote | Fish has different plugin ecosystem |
| Powerlevel10k config | Using Starship (cross-shell) |
| Amazon Q integration | Re-add if still using |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONF-01 | Phase 1 | Pending |
| CONF-02 | Phase 1 | Pending |
| ENV-01 | Phase 2 | Pending |
| ENV-02 | Phase 2 | Pending |
| ENV-03 | Phase 2 | Pending |
| ENV-04 | Phase 2 | Pending |
| SEC-01 | Phase 2 | Pending |
| SEC-02 | Phase 2 | Pending |
| SEC-03 | Phase 2 | Pending |
| TOOL-01 | Phase 3 | Pending |
| TOOL-02 | Phase 3 | Pending |
| TOOL-03 | Phase 3 | Pending |
| TOOL-04 | Phase 3 | Pending |
| TOOL-05 | Phase 3 | Pending |
| ABBR-01 | Phase 4 | Pending |
| ABBR-02 | Phase 4 | Pending |
| ABBR-03 | Phase 4 | Pending |
| ABBR-04 | Phase 4 | Pending |
| ABBR-05 | Phase 4 | Pending |
| ABBR-06 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0 ✓

---
*Requirements defined: 2025-02-05*
*Last updated: 2025-02-05 after initial definition*

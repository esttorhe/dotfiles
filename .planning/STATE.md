# Project State

## Current Position

Phase: 1 — Config Structure
Plan: Not yet created
Status: Ready to plan
Last activity: 2025-02-05 — Roadmap created

## Project Reference

See: .planning/PROJECT.md (updated 2025-02-05)

**Core value:** Working fish config preserving zsh functionality
**Current focus:** Phase 1 - Config Structure

## Accumulated Context

### Decisions
- Use abbreviations instead of aliases (fish-native approach)
- Drop zsh plugins, re-add individually if needed
- Starship stays (works with fish out of box)
- Use `private_fish` prefix for chezmoi permissions

### Notes
- User new to fish - keep patterns familiar where possible
- Testing on `fish` branch before committing to switch
- 4 phases total: structure → env → tools → abbreviations

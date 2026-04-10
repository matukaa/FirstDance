# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

FirstDance is a World of Warcraft retail addon that tracks the "First Dance" spell cooldown with an on-screen icon and TTS (text-to-speech) ready alert.

## Build & Packaging

There are no local build or test tools. Packaging is handled by GitHub Actions (`.github/workflows/package.yml`), which bundles the addon into `FirstDance.zip` and attaches it to GitHub releases.

To install manually: copy the repo folder into `World of Warcraft/_retail_/Interface/AddOns/FirstDance/`.

## Architecture

The addon is entirely contained in `FirstDance.lua` (monolithic single-file design typical of small WoW addons). `FirstDance.toc` declares the interface version, entry script, and `FirstDanceDB` as the SavedVariables key.

### Key subsystems in `FirstDance.lua`

- **DB / settings**: `InitDB()` initializes `FirstDanceDB` with defaults; all user settings are persisted there.
- **Icon frame**: `CreateCountdownIcon()` builds a movable frame with a cooldown swipe and countdown text. `StartCountdown()` / `StopCountdown()` drive its visibility. `UpdateCountdownText()` is called every 0.1 s via `C_Timer.NewTicker`.
- **TTS**: `SpeakText()` wraps `C_VoiceChat.SpeakText()`; `PlayReadySound()` fires it when the spell becomes ready.
- **Config panel**: `CreateConfigPanel()` produces a draggable settings window; toggled via `/firstdance` or `/fd`.
- **Event handler** (bottom of file): listens to `ADDON_LOADED`, `SPELL_UPDATE_COOLDOWN` (cooldown start/end detection), and `PLAYER_REGEN_DISABLED` (hide icon in combat).

### Spell IDs

| Constant | ID | Meaning |
|---|---|---|
| `SPELL_ID_LOADING` | 470677 | Spell on cooldown (countdown active) |
| `SPELL_ID_READY` | 470678 | Spell ready (fire TTS alert) |

### Version-compatibility helpers

`GetSpellIconTexture()` and `ClearCooldownFrame()` contain fallback code to handle API differences between WoW versions (e.g. `GetSpellTexture` vs `C_Spell.GetSpellTexture`).
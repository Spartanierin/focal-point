# Focal Point Release Checklist

Use this checklist before every release cut.

## 1) Scope Freeze
- Stop non-release feature work.
- Confirm the exact fixes/changes included in this release.
- Verify no open blocker bugs remain.

## 2) Version + Notes
- Update `FocalPoint.toc`:
  - `## Version: x.y.z`
- Update `CHANGELOG.md`:
  - Add/update release section.
  - Keep entries user-facing and grouped by `Added/Changed/Fixed/Removed`.
- Update `README.md` only if release-relevant user info changed.

## 3) Defaults + Data Consistency
- Confirm intended defaults in `Data/Defaults.lua`.
- If adopting live profile values as defaults:
  - compare explicitly,
  - apply only confirmed deltas,
  - avoid broad overwrite from SavedVariables.

## 4) Runtime Safety Checks
- `/reload` with no startup Lua errors.
- Open GUI via slash and minimap button.
- Toggle minimap button (open/close behavior).
- Open Editor + Inspector and switch units:
  - player, target, focus, pet, boss.
- Verify text rendering (especially `[name]`) on target/focus/boss.
- Verify combat-sensitive bars:
  - power, alt power, class power.
- Verify presets + apply path still work.

## 5) Visual Sanity Checks
- Sidebar button states readable:
  - normal, hover, pressed, active, disabled, danger, close utility.
- Welcome modal primary action styling still correct.
- Tool pages (Profiles/Text Builder/Tag DB) button roles render consistently.

## 6) Localization Checks
- German client: German strings present.
- English client: English strings present.
- Unsupported locales: fallback to English works.

## 7) Git Hygiene
- `git status` clean except intended files.
- Review final diff once.
- Commit with release message:
  - e.g. `Release x.y.z`
- Create tag:
  - `git tag vx.y.z`
- Verify tag target:
  - `git show --no-patch --oneline vx.y.z`

## 8) Package Sanity
- Confirm release package includes addon root `FocalPoint/`.
- Confirm `.toc`, `Init.xml`, and referenced files exist.
- Confirm no obsolete/temporary debug files are included.

## 9) Post-Release
- Keep one hotfix branch ready.
- Track first live feedback/errors for 24-48h.
- Log any follow-up fixes into `CHANGELOG.md` (`Unreleased`).

# Theming and Glass Rendering Research Plan

## Goal
Ensure PickPalette supports reliable light/dark/system theming while allowing users to enable or disable liquid glass styling without introducing rendering regressions.

## Current State Audit

### Theming
- App theme mode is persisted in `AppState.appearance` with `system`, `light`, and `dark`.
- `NSApp.appearance` is applied at launch and updated from the Appearance settings tab.

### Glass Toggle
- Glass mode is persisted in `AppState.useGlassStyle`.
- Most UI surfaces already use the `useGlassStyle` environment key.
- Before this branch, some components still forced material rendering and bypassed the toggle.

### Performance Risks Identified
- Color wheel image generation was recomputed in the canvas path during frequent view updates.
- HSL square spectrum rendering recalculated a dense pixel grid repeatedly.
- Some always-on material surfaces increased composition cost even with glass disabled.

## Implemented in Branch `codex/theme-glass-research-plan`

### 1. Global Glass Behavior Consistency
- Added `AppState.effectiveGlassStyle` to honor:
  - user toggle (`useGlassStyle`), and
  - macOS accessibility setting `Reduce Transparency`.
- Updated SwiftUI roots to inject `useGlassStyle` from observable app state so changes apply live.
- Updated outlier views to respect the toggle:
  - widget swatch ring,
  - editor overlay controls,
  - HUD background rendering.

### 2. Theme Consistency Improvements
- HUD now follows app appearance (`light`, `dark`, or `system`) instead of forcing dark-only styling.
- HUD border/text colors adapt to current appearance mode.

### 3. Rendering Performance Optimizations
- Added in-memory caching for generated spectrum assets:
  - RGB color wheel CGImage cache keyed by size.
  - HSL spectrum CGImage cache keyed by size + quantized lightness.
- Cache entry limits are enforced to bound memory use.
- Result: expensive bitmap generation is avoided on repeated renders.

## Validation Done
- Built with:
  - `xcodebuild -project PickPalette.xcodeproj -scheme PickPalette -configuration Debug build CODE_SIGNING_ALLOWED=NO`
- Result: `BUILD SUCCEEDED`.

## Next Profiling Steps (Recommended)
1. Run Instruments `Core Animation` and `Time Profiler` while:
   - toggling glass on/off,
   - switching dark/light/system modes,
   - dragging in spectrum picker and layout editor.
2. Collect baseline vs optimized frame pacing and CPU time in:
   - `SpectrumPickerView`,
   - editor overlay interactions,
   - popover open/close animations.
3. Define pass thresholds:
   - no visible stutter during spectrum drag,
   - no sustained CPU spikes from repeated spectrum redraws,
   - glass-off mode uses solid surfaces across all primary UI regions.

## Follow-up Enhancements
- Add debug telemetry counters for spectrum cache hit/miss rates.
- Optionally add a dedicated `Performance Mode` switch to disable nonessential shadows/animations on low-power devices.

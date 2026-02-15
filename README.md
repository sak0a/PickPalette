<p align="center">
  <img src="PickPalette/Assets.xcassets/AppIcon.appiconset/PickPalette_Logo_256.png" width="128" alt="PickPalette Icon">
</p>

<h1 align="center">PickPalette</h1>

<p align="center">
  A lightweight macOS menu bar color picker and palette manager for designers and developers.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6-orange?style=flat-square" alt="Swift">
  <img src="https://img.shields.io/badge/UI-SwiftUI%20%2B%20AppKit-purple?style=flat-square" alt="UI Framework">
  <img src="https://img.shields.io/badge/dependencies-none-brightgreen?style=flat-square" alt="Dependencies">
</p>

---

## Features

**Eyedropper** — Pick any color from your screen using a high-performance ScreenCaptureKit-powered sampler with a 15x15 grid magnifier loupe.

**Color Spaces** — Work across RGB, HSL, HSB, CMYK, and Hex with real-time conversion between all formats.

**Smart Formats** — Copy colors as HEX, HEXA, RGBA, HSLA, HSBA, CMYK, or define your own output formats with a token-based system.

**Palette Management** — Save, organize, and reuse color palettes. Recently picked colors are tracked automatically.

**Spectrum Picker** — Full color wheel (RGB mode) or rectangular saturation/lightness picker (HSL/HSB modes) with cached rendering for smooth performance.

**Customizable Layout** — Free-form widget canvas editor with snap guides — arrange the picker UI exactly how you want it.

**Global Hotkey** — Trigger the eyedropper from anywhere with a configurable system-wide shortcut (default: `⌥⇧C`).

**HUD Notification** — A floating glass-styled panel shows the picked color at the top of your screen, auto-dismissing after a few seconds.

**Glass Morphism** — Optional frosted glass styling that respects system accessibility settings and adapts to Light, Dark, or System appearance.

**Launch at Login** — Start PickPalette automatically when you log in via native ServiceManagement integration.

## Installation

1. Clone the repository
   ```bash
   git clone https://github.com/sak0a/PickPalette.git
   ```
2. Open `PickPalette.xcodeproj` in Xcode 15.2+
3. Build and run (⌘R)

> On first launch, PickPalette will request Screen Recording permission for the eyedropper to work.

## Usage

PickPalette lives in your menu bar. Click the icon to open the color picker popover, or press the global hotkey to activate the eyedropper directly.

| Action | Default Shortcut |
|---|---|
| Open Popover | Click menu bar icon |
| Activate Eyedropper | `⌥⇧C` |
| Copy Color | Click format in popover |

## Built With

- **SwiftUI** — Primary UI framework
- **AppKit** — Menu bar, window management, HUD panels
- **ScreenCaptureKit** — High-performance screen pixel sampling
- **Carbon** — Global hotkey registration
- **CoreImage / CoreGraphics** — Image processing and rendering

Zero external dependencies — built entirely on Apple frameworks.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15.2+ to build from source

## License

This project is provided as-is for personal and educational use.

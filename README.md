<div align="center">
  <img src="AppIcon.jpg" alt="ThocKey Logo" width="140" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);">
  <h1>ThocKey</h1>
  <p><strong>Bring the satisfying acoustic feel of mechanical keyboards to macOS.</strong></p>

  [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
  [![Platform: macOS 14+](https://img.shields.io/badge/Platform-macOS%2014%2B-lightgrey.svg)]()
  [![Swift: 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)]()
  [![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](docs/CONTRIBUTING.md)
</div>

<br/>

**ThocKey** is a modern, lightweight macOS menu-bar application built with SwiftUI and AVFoundation. It simulates the acoustic feedback of mechanical switches on every key press and release across your entire operating system.

Equipped with a built-in **Audio Customizer Studio**, ThocKey allows you to import raw recordings, visually trim waveforms down to the millisecond, split clips into press/release pairs, and map unique sound effects to individual keys.

---

## ✨ Features

- 🎧 **Rich Built-in Sound Packs:** Includes *Thocky (Original)*, *Creamy*, *Clicky*, *Quiet*, and *Fah (Meme)* out of the box.
- 🎚️ **Waveform Audio Customizer:** Visually trim audio, eliminate microphone silence, split press/release sounds, amplify gain, and apply intelligent anti-click micro-fades.
- ⌨️ **Per-Key Custom Remapping:** Assign distinct sound effects to specific keys (e.g. Return, Spacebar, Backspace, or meme sounds like *Fah (Meme)*).
- 🎛️ **Menu-Bar Quick Controls:** Fast access to mute/enable toggles, volume presets, favorite pack switching, and timed pauses (15m / 30m / 1h).
- ⚡ **Ultra Low-Latency Playback:** Powered by a pooled `AVAudioEngine` CoreAudio pipeline with pre-buffered in-memory PCM caching.
- 🎨 **Warm Studio Aesthetic:** Beautiful dark, light, and system-adaptive UI with interactive typing test pads.
- 🔒 **100% Private & Offline:** Zero analytics, zero data storage, zero network access. Never records keystrokes.

---

## 📚 Documentation

Explore the comprehensive documentation for users and developers:

| Document | Description |
| :--- | :--- |
| 📖 **[User Guide](docs/USER_GUIDE.md)** | Step-by-step walkthrough of ThocKey Studio, importing audio, waveform trimming, key remapping, and favorites. |
| 🔧 **[Troubleshooting & FAQ](docs/TROUBLESHOOTING.md)** | Resolving macOS Accessibility permission prompts, Secure Input mode, audio device switching, and common questions. |
| 📦 **[Packaging & Distribution](docs/DISTRIBUTION.md)** | Guide to building release DMG binaries, Developer ID code signing, and Apple Notarization. |
| 🤝 **[Contributing Guidelines](docs/CONTRIBUTING.md)** | Instructions for setting up development environments, testing, architecture patterns, and submitting PRs. |
| 🎵 **[Sound Sources & Attribution](ThocKey/Sounds/SOURCES.md)** | Credits and CC0 Public Domain licensing details for bundled switch audio. |

---

## 🚀 Quick Start

### Option 1: Download Pre-built Release (`.dmg`)
1. Download the latest `ThocKey.dmg` from [Releases](https://github.com/yourusername/ThocKey/releases).
2. Drag **ThocKey.app** into your `/Applications` folder.
3. Open ThocKey and enable **Accessibility Permissions** in **System Settings > Privacy & Security > Accessibility** when prompted.

### Option 2: Build from Source
```bash
# Clone repository
git clone https://github.com/yourusername/ThocKey.git
cd ThocKey

# Build with Xcode CLI
xcodebuild -project ThocKey.xcodeproj -scheme ThocKey -destination 'platform=macOS' build
```

---

## ⌨️ Global Keyboard Shortcuts

| Shortcut | Function |
| :--- | :--- |
| <kbd>⌘ Command</kbd> + <kbd>⇧ Shift</kbd> + <kbd>M</kbd> | **Toggle Sound Mute / Unmute** (Global) |

---

## 🏗️ Tech Stack & Architecture

- **Language & Framework:** Swift 5.9+, SwiftUI, AppKit
- **Audio Engine:** `AVFoundation`, `AVAudioEngine`, `AVAudioPlayerNode`, `AVAudioMixerNode`
- **Audio Processing:** `AVAssetReader`, `AVAudioFile` for waveform analysis and high-speed offline sample rendering
- **Keyboard Hook:** `NSEvent.addGlobalMonitorForEvents` & `NSEvent.addLocalMonitorForEvents`
- **Persistence:** Atomic JSON storage with versioned schema migration (`CatalogManifest`)

---

## 🛡️ Privacy & Security

ThocKey is designed with strict **Privacy by Design**:
- Keystrokes are monitored solely for triggering local audio playback.
- **No text, keystroke history, or logging** is ever captured or written to disk.
- Automatically suspends global monitors during macOS **Secure Input Mode** (such as typing in password fields or secure terminals).

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details. Bundled sound samples are distributed under [CC0 1.0 Universal Public Domain](ThocKey/Sounds/SOURCES.md).

# 🤝 Contributing to ThocKey

We love contributions! Whether you're adding new built-in sound packs, improving UI animations, or optimizing the AVFoundation audio engine, your help makes ThocKey better for everyone.

---

## 🛠️ Development Setup

### Prerequisites
- **macOS Sonoma (14.0+)**
- **Xcode 15.0+**
- Swift 5.9+

### Getting the Code
```bash
git clone https://github.com/yourusername/ThocKey.git
cd ThocKey
open ThocKey.xcodeproj
```

### Building & Running
You can build directly from Xcode by selecting the **ThocKey** scheme, or run from the command line:

```bash
# Build Debug binary
xcodebuild -project ThocKey.xcodeproj -scheme ThocKey -destination 'platform=macOS' build

# Run unit and UI tests
xcodebuild -project ThocKey.xcodeproj -scheme ThocKey -destination 'platform=macOS' test
```

---

## 🏗️ Architecture Overview

ThocKey is built with modern **SwiftUI** and native macOS **AppKit / AVFoundation** APIs:

- **`AppModel.swift`**: The central state manager (`@MainActor ObservableObject`). Coordinates sound packs, active selections, volume, preferences, and permissions.
- **`AudioPlaybackEngine.swift`**: Low-latency CoreAudio / AVFoundation playback engine. Uses a pool of `AVAudioPlayerNode` instances connected through an `AVAudioMixerNode` with in-memory PCM buffer caching.
- **`KeyboardMonitor.swift`**: Manages global (`NSEvent.addGlobalMonitorForEvents`) and local (`NSEvent.addLocalMonitorForEvents`) keyboard event taps.
- **`LocalCatalogStore.swift`**: Versioned JSON storage (`catalog.json`) managing sound items, custom packs, and key mappings with automatic atomic backups.
- **`AudioProcessingService.swift`**: High-performance audio extraction, trimming, gain adjustment, micro-fade application, and waveform sample computation via `AVAssetReader` / `AVAudioFile`.

---

## 🎵 Contributing New Built-In Sounds

If you want to contribute a new default sound pack to ThocKey:

1. **Licensing Requirement:** Audio recordings MUST be licensed under **CC0 (Public Domain)** or a permissive open-source license with proof of provenance.
2. **Audio Specs:**
   - Format: 44.1kHz or 48kHz, 16-bit or 24-bit WAV / AIFF.
   - Clean, isolated keystrokes with zero background noise.
   - Separate press (down) and release (up) samples where possible.
3. Add the sound files into `ThocKey/Sounds/` and document attribution in `ThocKey/Sounds/SOURCES.md`.
4. Register the new pack in `BuiltInSoundData` in `SoundModels.swift`.

---

## 📋 Pull Request Guidelines

1. **Keep PRs Focused:** One feature or fix per pull request.
2. **Coding Standards:** Follow standard Swift conventions, 4-space indentation, descriptive naming, and avoid force unwrapping.
3. **Tests:** Ensure all existing unit tests in `ThocKeyTests/` pass before submitting.
4. **Documentation:** If introducing a new macOS behavior, error resolution, or quirk, update `Error.md` and relevant docs.

---

Thank you for making typing on macOS more satisfying! 🎉

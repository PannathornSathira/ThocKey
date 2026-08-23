<div align="center">
  <img src="AppIcon.jpg" alt="ThocKey Logo" width="160" height="160">
  <h1>ThocKey</h1>
  <p><strong>A macOS menu-bar app for customizing your keyboard sound.</strong></p>

  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![Platform: macOS](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)]()
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)]()
</div>

<br/>

ThocKey is a macOS 14 SwiftUI menu-bar app that lets you customize the sound of your keyboard. Bring the satisfying *thock*, *click*, or *clack* of a premium mechanical keyboard directly to your Mac, or use any custom sound for your keystrokes!

## Features

- 🎧 **Custom Key Sounds:** Play a satisfying sound on every key down and key up event.
- 🎛️ **Menu-Bar Native:** Lives quietly in your macOS menu bar for quick access to toggle sounds on and off.
- 🛠️ **Customizable:** Import, trim, split, rename, and map WAV, MP3, AIFF, or M4A sounds from ThocKey Studio.
- ⚡ **Lightweight:** Built with SwiftUI and AVFoundation for minimal resource usage.

## Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/ThocKey.git
   cd ThocKey
   ```

2. **Build and Run:**
   Open `ThocKey.xcodeproj` in Xcode (requires Xcode 15+ and macOS 14+), or build from the command line:
   ```bash
   xcodebuild -project ThocKey.xcodeproj -scheme ThocKey -destination 'platform=macOS' build
   ```

3. **Accessibility Permissions:**
   The app requires Accessibility permissions to monitor global keystrokes. When you first launch the app, macOS will prompt you to grant this permission in **System Settings > Privacy & Security > Accessibility**.

## How to Use Custom Sounds

Open **ThocKey Studio → Sound Library → Import Audio**. Imported sounds are validated and copied into `~/Library/Application Support/ThocKey/Sounds`; metadata and pack mappings are stored locally in a versioned catalog. Audio files must be 50 MB or smaller and no longer than 60 seconds.

Use **Customize** to trim a recording or split it into key-down and key-up sounds. Create reusable combinations from **Sounds & Packs → New Pack**, then assign special keys from **Key Mappings**.

## Development

- **App Structure:** `AppModel` coordinates UI state, while `LocalCatalogStore`, `AudioPlaybackEngine`, and `KeyboardMonitor` own persistence, playback, and global event monitoring respectively. `SoundManager` remains only as a compatibility type alias.
- **Distribution:** The project is configured for direct Developer ID distribution with Hardened Runtime. App Sandbox remains disabled because the MVP depends on Accessibility-authorized global keyboard monitoring; sign and notarize release builds before publishing.
- **Testing:** 
  Run unit and UI tests from Xcode, or via the command line:
  ```bash
  xcodebuild -project ThocKey.xcodeproj -scheme ThocKey -destination 'platform=macOS' test
  ```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

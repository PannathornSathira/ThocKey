# 📖 ThocKey User Guide

Welcome to the **ThocKey User Guide**! Whether you want to turn your silent laptop keyboard into a rich mechanical thock or create custom sound effects for special keys, this guide walks you through every feature.

---

## 📑 Table of Contents

1. [First Launch & Permissions](#1-first-launch--permissions)
2. [Menu Bar Quick Controls](#2-menu-bar-quick-controls)
3. [Exploring ThocKey Studio](#3-exploring-thockey-studio)
   - [Sounds & Packs](#-sounds--packs)
   - [Key Mappings](#-key-mappings)
   - [Sound Library & Importing Audio](#-sound-library--importing-audio)
   - [Waveform Audio Customizer](#-waveform-audio-customizer)
   - [Settings & Appearance](#-settings--appearance)
4. [Keyboard Shortcuts](#4-keyboard-shortcuts)
5. [Storage & Data Management](#5-storage--data-management)
6. [Privacy & Security](#6-privacy--security)

---

## 1. First Launch & Permissions

Because ThocKey plays sounds in response to typing across all your macOS apps (browsers, code editors, chat apps, etc.), macOS requires **Accessibility Permissions**.

> [!NOTE]
> **Why Accessibility?**
> ThocKey uses macOS's `NSEvent.addGlobalMonitorForEvents` to detect when a key is pressed so it can play the matching audio sample in real-time. **ThocKey never records, stores, or transmits keystrokes or text.**

### Step-by-Step Setup:
1. When you open ThocKey for the first time, a macOS system prompt will ask for Accessibility access.
2. Click **Open System Settings** (or go to **System Settings > Privacy & Security > Accessibility**).
3. Find **ThocKey** in the list and toggle the switch **ON**.
4. Switch back to ThocKey. The app will automatically detect the permission and begin playing keystroke sounds immediately!

*(If the status still shows "Permission Required", click the **Check Status** button in ThocKey Studio → Settings).*

---

## 2. Menu Bar Quick Controls

ThocKey lives in your macOS menu bar with a keyboard icon (`⌨️`). Clicking the menu bar icon gives you immediate control without opening the main window:

<div align="center">
  <img src="../AppIcon.jpg" alt="ThocKey Icon" width="90">
</div>

- **Mute / Enable Toggle:** Instantly silence or resume sounds (or use `⌘ ⇧ M`).
- **Timed Pause:** Temporarily pause sounds for **15 minutes**, **30 minutes**, or **1 hour** (great for meetings or screen sharing).
- **Master Volume:** Quick preset volume selector (100%, 75%, 50%, 25%, 0%).
- **Preview Active Sound:** Listen to the currently selected key sound.
- **Active Pack & Favorites:** Quickly switch between your built-in, customized, or favorite sound packs.
- **Open Studio / Settings:** Open the main ThocKey Studio interface.

---

## 3. Exploring ThocKey Studio

Open **ThocKey Studio** from the menu bar to access the full visual suite.

### 🎧 Sounds & Packs
The central hub for selecting, testing, and managing your sound packs:
- **Active Sound Pack:** View and switch between default packs (*Thocky*, *Creamy*, *Clicky*, *Quiet*, *Fah (Meme)*) and your custom packs.
- **Star / Favorite:** Mark your favorite packs to pin them to the top of your menu bar for fast switching.
- **Interactive Typing Test Pad:** A smooth playground to test sound feel, key rhythm, and responsiveness right inside the app.
- **Master Volume Slider:** Fine-tune audio playback volume from 0% to 100%.
- **New Pack:** Create a custom sound pack with your own press and release sounds.

---

### ⌨️ Key Mappings
Want a unique sound for specific keys? You can remap individual keys in any sound pack:
- **Modifier & Special Keys:** Assign distinct sounds to **Return/Enter**, **Spacebar**, **Backspace/Delete**, **Escape**, **Tab**, **Shift**, **Command**, and more.
- **Meme & Specialty Sounds:** Set your favorite meme sound (like *Fah (Meme)*) to trigger every time you press Enter or Space!
- **Default Option:** Easily revert any key back to the pack's default keystroke sound.

---

### 📚 Sound Library & Importing Audio
Manage all the sound samples stored on your machine:
- **Import Audio:** Add any `.wav`, `.mp3`, `.aiff`, or `.m4a` file (up to 50 MB and 60 seconds).
- **Audio Previews:** Click the play button to preview press (key-down) and release (key-up) audio.
- **Attach Release Sound:** Combine separate press and release sound files into a single unified sound item.
- **Rename & Delete:** Rename sound items or delete imported sounds with safe automatic key-unbinding.

---

### 🎚️ Waveform Audio Customizer
Turn any raw sound recording into the perfect keystroke audio:

1. **Waveform Visualizer:** Displays the amplitude curve of your audio clip.
2. **Precision Millisecond Trimming:** Drag the start and end sliders or click `-5ms` / `+5ms` step buttons to cut out background noise and silence before the key impact.
3. **Split Mode (Press & Release):** Cut a single continuous recording of a keystroke into two parts: the key-press and the key-release!
4. **Gain Booster:** Amplify quiet recordings up to **2.5x** volume.
5. **Anti-Click Micro-Fade:** Applies an intelligent 5ms exponential micro-fade at start and end to eliminate audio pops and clicks.
6. **Live Test Before Saving:** Type directly inside the customizer test field to feel the trimmed sound with real keyboard rhythm before committing.

---

### ⚙️ Settings & Appearance
- **Theme Preference:** Switch between **Warm Studio Light**, **Deep Walnut Dark**, or follow your macOS **System Theme**.
- **Real-Time Permission Status:** Live indicator showing whether Accessibility is active.
- **Check Status / Open Settings:** Quick diagnostic and launcher for macOS System Settings.
- **Storage Path:** Direct link to your local sounds catalog directory.

---

## 4. Keyboard Shortcuts

| Shortcut | Action | Scope |
| :--- | :--- | :--- |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>M</kbd> | **Toggle Sound Mute / Unmute** | Global (works anywhere in macOS) |
| <kbd>Esc</kbd> | Close sheet / modal dialogs | Inside Studio |

---

## 5. Storage & Data Management

ThocKey stores all your custom audio and configuration locally on your Mac:

```text
~/Library/Application Support/ThocKey/
├── Sounds/                # Imported and trimmed WAV audio files
├── catalog.json           # Your packs, sound metadata, and key mappings
└── catalog.backup.json    # Automatic backup copy
```

> [!TIP]
> **Backing Up:** You can back up or migrate your sound packs to another Mac simply by copying the `~/Library/Application Support/ThocKey/` folder!

---

## 6. Privacy & Security

ThocKey is designed from the ground up with **Privacy by Design**:
- 🔒 **Zero Data Collection:** No keystroke text, metadata, or telemetry is ever stored or transmitted.
- 📶 **100% Offline:** The app makes zero network connections.
- 🛡️ **Secure Input Awareness:** Whenever you type in password fields or secure terminals, macOS automatically suspends event monitors to safeguard your credentials.

---

*Need help or experiencing issues? Check the [Troubleshooting Guide](TROUBLESHOOTING.md) or open an issue on GitHub.*

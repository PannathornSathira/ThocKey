# 🔧 ThocKey Troubleshooting & FAQ

Encountering an issue? Here are the solutions to the most common macOS quirks and audio questions.

---

## 📑 Frequently Addressed Issues

- [1. No sound when typing in other apps](#1-no-sound-when-typing-in-other-apps)
- [2. App says "Permission required" even after enabling in System Settings](#2-app-says-permission-required-even-after-enabling-in-system-settings)
- [3. No sound when typing passwords or in Terminal / iTerm](#3-no-sound-when-typing-passwords-or-in-terminal--iterm)
- [4. Audio clicks or pops at the beginning or end of keystrokes](#4-audio-clicks-or-pops-at-the-beginning-or-end-of-keystrokes)
- [5. Sound stopped working after waking from sleep or changing headphones](#5-sound-stopped-working-after-waking-from-sleep-or-changing-headphones)
- [6. How do I reset or clear my custom sounds?](#6-how-do-i-reset-or-clear-my-custom-sounds)

---

## 1. No sound when typing in other apps

**Cause:** ThocKey needs macOS Accessibility permissions to monitor global key presses.
**Solution:**
1. Open **System Settings > Privacy & Security > Accessibility**.
2. Make sure **ThocKey** is switched **ON**.
3. If it is already ON, see [Section 2](#2-app-says-permission-required-even-after-enabling-in-system-settings) below.
4. Make sure ThocKey is not muted (<kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>M</kbd>) or temporarily paused in the menu bar.

---

## 2. App says "Permission required" even after enabling in System Settings

**Cause:** macOS maintains a security signature cache for Accessibility permissions. When updating or rebuilding apps, macOS can sometimes lose track of the permission state.

**Solution:**
1. Open **System Settings > Privacy & Security > Accessibility**.
2. Select **ThocKey** from the list.
3. Click the **minus (`-`)** button at the bottom of the list to remove the old record completely.
4. Switch back to ThocKey, open **Settings**, and click **Check Status** or **Open Settings** to prompt a fresh permission request.
5. Re-enable ThocKey in the list.

---

## 3. No sound when typing passwords or in Terminal / iTerm

**Cause:** **macOS Secure Input Mode** (Normal & Expected Security Feature).
When you are focused on a password input field, lock screen, or a terminal running with "Secure Keyboard Entry" enabled, macOS intentionally blocks *all* third-party apps from intercepting key events to prevent keyloggers.

**Solution:**
- This is normal security behavior. Keystroke sounds will automatically resume as soon as you click outside the password or secure input field.

---

## 4. Audio clicks or pops at the beginning or end of keystrokes

**Cause:** Raw audio recordings that start or end abruptly at a non-zero waveform amplitude can create an audible DC offset pop.

**Solution:**
1. Open **ThocKey Studio → Sound Library**.
2. Click **Customize** on the sound.
3. Ensure **"Apply Anti-Click Micro-Fade"** is turned **ON**. This applies an intelligent 5ms fade-in and fade-out to guarantee smooth audio transitions.
4. Adjust the start slider slightly past any background noise or microphone rumble.

---

## 5. Sound stopped working after waking from sleep or changing headphones

**Cause:** macOS audio route changes (plugging/unplugging headphones, sleep/wake cycles) can temporarily disrupt the audio output engine.

**Solution:**
- ThocKey automatically restarts its internal `AVAudioEngine` upon the next keystroke. If silence persists, simply toggle mute off and on with <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>M</kbd>.

---

## 6. How do I reset or clear my custom sounds?

Your custom packs and sounds live in your user Application Support directory:

- To reset everything back to factory defaults:
  1. Quit ThocKey (<kbd>⌘</kbd> + <kbd>Q</kbd> or via menu bar).
  2. Open Finder, press <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>G</kbd>, and enter:
     ```text
     ~/Library/Application Support/ThocKey
     ```
  3. Delete the `ThocKey` folder (or move it to Trash).
  4. Relaunch ThocKey.

---

*Still having trouble? Please [open an issue on GitHub](https://github.com/yourusername/ThocKey/issues) with your macOS version and details.*

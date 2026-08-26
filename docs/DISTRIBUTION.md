# 📦 Packaging & Distributing ThocKey

This guide explains how to build, package into a `.dmg`, code sign, and notarize ThocKey for direct distribution on macOS.

---

## 💡 Why Direct `.dmg` Distribution?

ThocKey requires macOS Accessibility permissions (`NSEvent.addGlobalMonitorForEvents` / `AXIsProcessTrusted`) to play typing sounds across all applications on your Mac.

Apple's **Mac App Store strictly mandates App Sandboxing**, which blocks global keyboard monitoring across third-party apps to prevent keylogging. Therefore, ThocKey is distributed directly via **DMG downloads** (e.g., GitHub Releases, personal websites, Homebrew).

---

## 🚀 Building a Release `.app`

1. Select **Any Mac** in Xcode.
2. In Xcode, choose **Product > Archive** (or run via CLI):
   ```bash
   xcodebuild -project ThocKey.xcodeproj \
              -scheme ThocKey \
              -configuration Release \
              -archivePath build/ThocKey.xcarchive \
              archive
   ```
3. Export the archive to obtain `ThocKey.app`.

---

## 💿 Creating a `.dmg` Installer

You can use the open-source tool [`create-dmg`](https://github.com/create-dmg/create-dmg) or macOS's built-in `hdiutil`:

```bash
# Install create-dmg via Homebrew
brew install create-dmg

# Create a drag-and-drop installer DMG
create-dmg \
  --volname "ThocKey" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "ThocKey.app" 175 190 \
  --app-drop-link 425 190 \
  "ThocKey-Installer.dmg" \
  "/path/to/exported/ThocKey.app"
```

---

## 🔐 Developer ID Signing & Notarization

To prevent macOS Gatekeeper warnings on fresh downloads:

### 1. Sign with Developer ID
```bash
codesign --deep --force --verify --verbose \
  --options runtime \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  --entitlements ThocKey/ThocKey.entitlements \
  ThocKey.app
```

### 2. Notarize with Apple
```bash
xcrun notarytool submit ThocKey-Installer.dmg \
  --keychain-profile "AC_PASSWORD" \
  --wait
```

### 3. Staple Notarization Ticket
```bash
xcrun stapler staple ThocKey-Installer.dmg
```

---

## 🏷️ Publishing GitHub Releases

1. Create a Git tag (e.g., `v1.0.0`) and push to GitHub:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. Go to **Releases > Draft a new release** on GitHub.
3. Attach `ThocKey-Installer.dmg`.
4. Publish release for users to download freely!

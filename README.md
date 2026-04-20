# RecordApp — Hands-Free Voice Note Taker

Always-on voice recorder for macOS and Android. Say **"Genie, start recording"** to begin, **"Genie, stop"** to end. Notes are saved as `.txt` files locally. No cloud required (macOS uses Whisper for offline transcription).

---

## Repository Layout

```
RecordApp-macOS/        Swift app — menu bar, Whisper transcription
RecordApp-Android/      Kotlin app — foreground service, live STT
scripts/mac/            Build + run scripts for macOS
scripts/android/        Build + install scripts for Android
recordings/             Your notes land here (macOS) — not in git
record_app.md           Full design doc + decision history
```

---

## macOS Setup (new machine)

### Prerequisites
```bash
# 1. Install Xcode Command Line Tools (includes Swift)
xcode-select --install

# 2. Install Homebrew (if not already)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/brew.sh/install/HEAD/install.sh)"
```

### Clone and build
```bash
git clone git@github.com:goelhss/recording_app.git
cd recording_app
bash scripts/mac/build.sh    # downloads WhisperKit (~300 MB first time), compiles, signs
bash scripts/mac/run.sh      # launches app in menu bar
```

### First run
- Look for the 🐱 cat icon in your menu bar
- Say **"Genie, start recording"** → speak → **"Genie, stop"**
- On first recording, Whisper downloads its model (~150 MB) — takes ~30 sec, then fully offline forever
- Notes saved to `recordings/` folder next to the scripts

### macOS voice commands
| Say | Action |
|---|---|
| Genie, start recording | Begin recording |
| Genie, stop | Stop and transcribe |
| Genie, play back latest | Read last note aloud |
| Genie, how many notes today | Count today's notes |
| Genie, delete latest | Delete last note |
| Genie, convert to text | Batch-transcribe any unconverted audio files |

---

## Android Setup (new machine)

### Prerequisites
```bash
# 1. Install Java 17
brew install openjdk@17
echo 'export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# 2. Install adb (to push APK to phone)
brew install android-platform-tools

# 3. Install Gradle (to build)
brew install gradle

# 4. Install Android SDK command-line tools
brew install --cask android-commandlinetools

# 5. Install Android SDK platform + build tools
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
yes | sdkmanager --sdk_root="$ANDROID_HOME" \
    "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

Add to `~/.zshrc` so these persist across terminals:
```bash
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
```

### Clone and build
```bash
git clone git@github.com:goelhss/recording_app.git
cd recording_app/RecordApp-Android

gradle wrapper --gradle-version 8.6
chmod +x gradlew

export PATH="/opt/homebrew/opt/openjdk@17/bin:$PATH"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
./gradlew assembleDebug
```
APK is at `app/build/outputs/apk/debug/app-debug.apk`

### Install on your phone
```bash
# On your phone: Settings → About Phone → tap Build Number 7 times
# Then: Settings → Developer Options → enable USB Debugging
# Plug in phone via USB, tap Allow on phone

adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.recordapp/.MainActivity
```

### Run on emulator (no phone needed)
```bash
# Install emulator + system image (one time, ~1.5 GB download)
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
yes | sdkmanager --sdk_root="$ANDROID_HOME" \
    "emulator" "system-images;android-34;google_apis;arm64-v8a"

# Create virtual device
echo "no" | avdmanager create avd -n RecordApp_AVD \
    -k "system-images;android-34;google_apis;arm64-v8a" \
    --device "pixel_6"

# Start emulator
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
emulator -avd RecordApp_AVD &

# Wait for boot, then install
adb wait-for-device
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.recordapp/.MainActivity
```

### Android voice commands (same as macOS)
| Say | Action |
|---|---|
| Genie, start recording | Begin recording |
| Genie, stop | Stop and save note |
| Genie, play back latest | Read last note aloud |
| Genie, how many notes today | Count today's notes |
| Genie, delete latest | Delete last note |

Notes are saved to `Android/data/com.recordapp/files/recordings/` on the phone. Tap any note in the app list to read it.

---

## Using scripts (shortcut)

The `scripts/` folder wraps all of the above:

```bash
bash scripts/mac/build.sh        # build macOS app
bash scripts/mac/run.sh          # run macOS app
bash scripts/android/setup.sh    # check prerequisites
bash scripts/android/build.sh    # build Android APK
bash scripts/android/install.sh  # install to connected phone
```

---

## Notes saved at
- **macOS:** `recordings/` folder in the repo root
- **Android (phone):** `Android/data/com.recordapp/files/recordings/`
- **Android (emulator):** same path, accessible via `adb shell`

---

See `record_app.md` for full design decisions, bug history, and architecture details.

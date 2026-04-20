# Record App — Specification & Design History (Android + macOS)

---

## Build Status

### macOS

| Phase | Feature | Status |
|---|---|---|
| 1 | Menu bar app skeleton | ✅ Done |
| 1 | Microphone + SFSpeechRecognizer transcription | ✅ Done |
| 1 | Save notes to `record_app/recordings/` | ✅ Done |
| 1 | Start/Stop via menu click | ✅ Done |
| 1 | Build + sign script (`scripts/mac/build.sh`) | ✅ Done |
| 2 | Wake word + voice commands (all Hey Recorder phrases) | ✅ Done |
| 2 | Audible TTS confirmation for every command | ✅ Done |
| 2 | Append to last note (voice) | ✅ Done |
| 2 | Playback / read-back (latest + today's notes) | ✅ Done |
| 2 | Delete latest note (voice + menu) | ✅ Done |
| 2 | Switch storage mode by voice | ✅ Done |
| 2 | Note count / storage status by voice | ✅ Done |
| 2 | Audio-only recording mode → manual "Convert to text" | ✅ Done |
| 2 | WhisperKit integration (default mode) | ✅ Done |
| 2 | Tagging by voice | Not started |
| 2 | Search by keyword | Not started |
| 2 | Daily summarization | Not started |
| 2 | Reminders from notes | Not started |
| 2 | Email / share | Not started |
| 3 | Google Drive OAuth + sync | Not started |

**Last updated:** 2026-04-19

### Android

| Phase | Feature | Status |
|---|---|---|
| 1 | Project scaffold (Kotlin, Gradle, API 34) | ✅ Done |
| 1 | ForegroundService with mic permission | ✅ Done |
| 1 | SpeechRecognizer — always-on wake word + live STT | ✅ Done |
| 1 | Save notes to local storage (external files dir) | ✅ Done |
| 1 | Voice commands — start/stop/playback/delete/count | ✅ Done |
| 1 | TTS confirmation (TextToSpeech API) | ✅ Done |
| 1 | Start on boot (BootReceiver) | ✅ Done |
| 1 | Build + install scripts | ✅ Done |
| 2 | Offline Whisper transcription (whisper.cpp NDK) | Not started |
| 2 | Tagging, search, summarization | Not started |
| 3 | Google Drive sync | Not started |

---

## Overview

A hands-free audio note-taking app that runs always-on in the background, listens for voice commands, transcribes speech to text, and saves notes locally or to Google Drive. Available on Android and macOS.

---

## Recording Modes

Four modes are available, selectable in Settings. **Whisper is the default.**

| Mode | How it works | Quality | Internet? |
|---|---|---|---|
| **Whisper (default)** | Records `.caf` audio, then auto-transcribes on stop using WhisperKit (on-device neural model) | High | No — fully offline after first model download (~150 MB) |
| **Cloud STT** | Streams audio live to Apple's cloud speech API (SFSpeechRecognizer) during recording | Very high | Yes |
| **On-device STT** | Streams audio live to Apple's on-device model (SFSpeechRecognizer) | Low–Medium | No |
| **Audio only** | Records `.caf` file only — no auto-transcription. Manually trigger "Convert Audio Files to Text" from menu or by voice | N/A | No |

### Why Whisper is default

The app went through several transcription approaches before landing on Whisper:

1. **Cloud STT only (original):** Excellent accuracy, but requires internet. More importantly: during early testing, the cloud recognizer would sometimes produce zero transcription for entire sessions — the file would be empty even after a long recording. Root cause was an error storm from `requiresOnDeviceRecognition = false` conflicting with concurrent sessions.

2. **On-device STT as fallback:** Added after the cloud reliability issues. But on-device model quality is noticeably worse — lots of mis-recognitions, especially proper nouns and non-standard speech. User could hear the quality difference immediately.

3. **Audio-only mode:** A pragmatic workaround — record raw audio cleanly, transcribe later. Works reliably but is manual/two-step. Added a menu item and voice command to batch-convert all unconverted `.caf` files.

4. **WhisperKit (current default):** Best of all worlds — fully offline, high accuracy (whisper.cpp with Metal GPU acceleration on Mac), auto-transcribes on stop. First run downloads the model once (~150 MB). Every subsequent recording transcribes locally without internet. This is now the default.

---

## Key Design Decisions & Bug History

### Wake word misrecognition ("He Recorder")
Apple's SFSpeechRecognizer consistently transcribes "Hey Recorder" as "He Recorder" — it drops the Y. Fix: the wake word scanner accepts both `hey recorder` and `he recorder` as valid triggers.

### Two recognizer instances caused error storms
Original design had two concurrent SFSpeechRecognizer sessions — one for wake word detection, one for transcription. Running both cloud recognizers simultaneously flooded the log with "No speech detected" errors every ~0.3s and destabilized transcription. Fix: collapsed to a single `commandRecognizer` that does double duty — detects wake words AND captures transcript text during recording.

### Incremental text was garbled
Early code used `dropFirst(lastSeenText.count)` to extract new words as the recognizer revised its output. SFSpeechRecognizer continuously rewrites earlier words, so slicing produced fragments like "3", "ing", "1". Fix: stopped incremental extraction entirely — only flush `currentSessionBest` (the full best transcription) to disk when `result.isFinal` fires or the session ends with an error.

### "Convert" command fired with nothing to convert
The voice command for "convert audio to text" would trigger during recording sessions that had no audio files. The response "No unconverted audio files found" looped audibly. Fix: silent no-op if `unconvertedAudioFiles()` is empty.

### Files stored at predictable relative path
Notes are saved to `record_app/recordings/` by navigating 3 levels up from `Bundle.main.bundleURL` at runtime (app bundle → `build/mac/` → `build/` → `record_app/`). This keeps recordings parallel to the source code and scripts, independent of where the user cloned the repo.

### App icon visibility in menu bar
Original icon used an SF Symbol (microphone). On macOS it blended with other system icons and was hard to spot. Changed to emoji text: 🐱 when idle, 🙀 when recording. Immediately identifiable; user can Cmd-drag to position next to the clock.

### requiresOnDeviceRecognition = true produced zero transcription
When `onDeviceSTT` mode was first added, setting `requiresOnDeviceRecognition = true` caused complete silence — no text ever generated. The on-device Whisper model hadn't been downloaded on the user's Mac, so Apple's framework silently failed. Reverted to `false` for reliability; on-device mode still exists as an option but is no longer default.

---

## Voice Commands Reference

| Command | Action |
|---|---|
| **"Hey Recorder / Genie, Start"** | Begin a new recording session |
| **"Hey Recorder / Genie, Stop recording"** | End session and save note |
| **"Hey Recorder / Genie, Append to last note"** | Toggle recording (adds to existing note) |
| **"Hey Recorder / Genie, Convert to text"** | Batch-transcribe all `.caf` files without matching `.txt` |
| **"Hey Recorder / Genie, Play back latest"** | Read aloud the most recent note |
| **"Hey Recorder / Genie, Play back today's notes"** | Read aloud all notes from today |
| **"Hey Recorder / Genie, Delete latest"** | Delete most recent note (confirmation required) |
| **"Hey Recorder / Genie, Change to local storage"** | Switch save destination to local |
| **"Hey Recorder / Genie, Change to Google Drive"** | Switch save destination to Google Drive |
| **"Hey Recorder / Genie, Where are my notes?"** | Read back current storage mode |
| **"Hey Recorder / Genie, How many notes today?"** | Read back today's note count |

Wake words accepted: "Hey Recorder", "Hey Record", "He Recorder", "He Record", "Recorder", "Genie", "Jeanie", "Jeannie"

---

## Architecture (macOS)

```
RecordApp-macOS/
  Sources/RecordApp/
    AppDelegate.swift          — app entry point, starts AudioManager engine
    AudioManager.swift         — AVAudioEngine tap, SFSpeechRecognizer, whisper dispatch
    WhisperTranscriber.swift   — async WhisperKit wrapper (lazy model load)
    NoteStore.swift            — file I/O, RecordingMode enum, UserDefaults prefs
    StatusBarController.swift  — NSStatusItem menu, command handler, notifications
    SettingsWindowController.swift — NSPanel with mode/storage/log toggles
    VoiceCommand.swift         — command enum + VoiceCommandParser
    SpeechFeedback.swift       — ding (NSSound) + TTS (AVSpeechSynthesizer)
    Logger.swift               — debug log (off by default, toggle in Settings)

scripts/mac/
  build.sh   — swift package resolve + swift build + .app bundle + codesign
  run.sh     — pkill existing + open .app

build/mac/
  RecordApp.app              — built output (not in git)

recordings/                  — all notes saved here (parallel to scripts/)
  2026-04-19_14-32-01.txt
  2026-04-19_15-10-44.caf    — audio-only or pre-whisper recording
```

### Whisper flow (default mode)

1. User says "Genie, start" → `AudioManager.startRecording()` creates `.caf` file, writes audio via AVAudioEngine tap
2. User says "Genie, stop" → `AudioManager.stopRecording()` closes `.caf`, dispatches `Task { await WhisperTranscriber.shared.transcribe(...) }`
3. WhisperKit transcribes on GPU (Metal) — typically a few seconds for a short note
4. Transcript saved as `.txt` alongside `.caf`; `onWhisperComplete` callback fires
5. Menu bar shows "Transcribed: filename.txt" and sends a system notification

### File naming

Files use `yyyy-MM-dd_HH-mm-ss` timestamps as names. The `.caf` and `.txt` for the same recording share a base name, which is how `unconvertedAudioFiles()` knows which `.caf` files still need transcription.

---

## Platform Notes

### macOS
- Built with Swift + AppKit, no Xcode IDE required — uses Swift Package Manager CLI
- `LSUIElement = true` — no Dock icon, lives entirely in menu bar
- Microphone + speech recognition permissions via `RecordApp.entitlements` + ad-hoc codesign
- Requires macOS 14+ (for WhisperKit Metal support)
- WhisperKit model downloaded once from HuggingFace to `~/.cache/huggingface/` on first transcription

### Android
- Min SDK: Android 14 (API 34)
- Language: Kotlin, build system: Gradle 8.6
- `ForegroundService` with `foregroundServiceType="microphone"` — required on Android 14 for mic access from background
- `SpeechRecognizer` for always-on wake word detection and live transcription (same continuous-restart pattern as macOS SFSpeechRecognizer)
- Notes saved to `getExternalFilesDir(null)/recordings/` — app-specific, no storage permissions needed
- `TextToSpeech` for TTS command confirmation (equivalent of macOS AVSpeechSynthesizer)
- `BootReceiver` starts the service automatically after phone reboot
- Transcription mode: live STT via Google's SpeechRecognizer (online). Offline Whisper via whisper.cpp NDK planned for Phase 2.
- Notes directory: visible via Android file manager at `Android/data/com.recordapp/files/recordings/`

**Build steps:**
```
bash scripts/android/setup.sh   # one-time: checks Java, adb, generates gradlew
bash scripts/android/build.sh   # builds debug APK
bash scripts/android/install.sh # installs to connected phone via USB
```

---

## Not Yet Built

- Tagging by voice
- Keyword search
- Daily summarization (LLM digest)
- Reminders from notes
- Email / share
- Google Drive OAuth + sync
- Android app

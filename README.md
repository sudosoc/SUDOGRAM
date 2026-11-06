# SUDOGRAM

Private, personal Telegram client (TDLib + Flutter). Android first.

- **Ghost Mode**: no read receipts, no typing, no online status (blocked at one choke point, `GhostGateway`).
- **Hidden chats**: long-press the search button → biometric → hidden chats appear; re-lock on background.
- **No ads**: sponsored messages are never requested.
- **Smart Splitter**: long text is split at paragraph/sentence boundaries (Arabic + English aware).
- Arabic / English UI (RTL/LTR). Glass UI, with a Performance Mode that disables blur.

## Run

Without credentials the app starts in **demo mode** (fake data):

    flutter run

With a real account (get `api_id`/`api_hash` from https://my.telegram.org) and `libtdjson.so` in
`android/app/src/main/jniLibs/arm64-v8a/`:

    flutter run --dart-define=TG_API_ID=123 --dart-define=TG_API_HASH=abc

CI (`.github/workflows/android.yml`) builds TDLib and the APK; set repo secrets `TG_API_ID`, `TG_API_HASH`.
Never commit credentials or `libtdjson.so`.

## Status

Tested: splitter, ghost guard, TDLib gateway logic (against a fake transport).
Not yet tested: the native TDLib binding and the CI TDLib build against real Telegram.
Known gaps: TDLib DB encryption key (Keystore) is a TODO; sending a message may implicitly mark the chat read.

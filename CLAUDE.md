# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Running the App

```bash
# Run on Chrome (web) - use the batch script from PowerShell (not Git Bash)
cmd.exe /c C:\Users\qdlvm\aiface_run.bat

# Or directly with Flutter
flutter run -d chrome --web-port=5599

# Run on Android/iOS
flutter run
```

## Build Commands

```bash
flutter pub get                    # Install dependencies
flutter build apk                  # Android
flutter build web                  # Web
dart run build_runner build        # Regenerate Drift + Riverpod code after schema changes
dart run build_runner watch        # Watch mode for code generation
```

## Code Generation

Two systems require `build_runner`:
- **Drift ORM**: After changing `database.dart` table definitions → regenerates `database.g.dart`
- **Riverpod**: Only if `@riverpod` annotations are added (not currently used; providers are manual)

## Architecture Overview

### State Management — Riverpod (manual, no code generation)

All providers live in a single file: `lib/providers/providers.dart`. Key providers:
- `llmConfigProvider` (StateNotifier) — API keys + model selection, persisted to storage
- `llmServiceProvider` — derived from config, creates the correct LLM service via factory
- `chatControllerProvider` — orchestrates the full send→stream→parse→save→update-face flow
- `expressionProvider` (StateProvider) — the current face expression shown in the pixel widget
- `learningModeProvider` (StateProvider<bool>) — French learning mode toggle
- `messagesProvider` (StateNotifier) — current conversation messages

### LLM Service Layer — Strategy + Factory

`lib/services/llm/` contains an abstract `LlmService` interface with three implementations (OpenAI, Anthropic, OpenRouter). All support streaming via SSE. `LlmFactory` selects the right implementation from `LlmConfig`. Both streaming and fallback non-streaming paths exist.

### Expression System — bidirectional

The AI includes `[EXPRESSION:emotion]` tags in responses. `ChatController.sendMessage()` parses these via `parseExpression()` (in `utils.dart`), updates `expressionProvider`, and strips the tags before displaying text or calling TTS. The pixel face widget re-renders automatically on provider change.

### Memory System

Every 10 messages, `MemoryService` sends the last 10 messages to the LLM with an extraction prompt, parses JSON output, and inserts facts into the `memories` Drift table. On every send, the top memories (by importance + recency) are appended to the system prompt via `buildMemoryContext()`.

### System Prompt Selection

`ChatController.sendMessage()` reads `learningModeProvider` to choose between `AppConstants.defaultSystemPrompt` and `AppConstants.frenchLearningSystemPrompt` (both in `lib/core/constants.dart`), then appends the memory context string.

### Database — Drift ORM

Three tables: `conversations`, `messages`, `memories`. Web support requires:
- `web/sqlite3.wasm` — copied from drift devtools package
- `web/drift_worker.js` — compiled from `web/drift_worker.dart`

The `_openConnection()` function in `database.dart` uses `kIsWeb` to conditionally pass `DriftWebOptions`.

### Storage — Platform Split

- **Mobile**: `FlutterSecureStorage` for API keys
- **Web**: `SharedPreferences` (secure storage unavailable in browser)

This split is handled inside `LlmConfigNotifier` in `providers.dart`.

### Pixel Face

`lib/features/face/expression.dart` defines 10 expressions as 16×16 grids of palette indices (0–6). Palette: transparent, skin, eye-dark, mouth-pink, blush-pink, highlight-white, shadow-peach. `getBlinkFrame()` generates a blink by replacing eye pixels with skin tone at rows 5–6.

## Key File Locations

| Concern | File |
|---|---|
| All providers | `lib/providers/providers.dart` |
| System prompts & constants | `lib/core/constants.dart` |
| LLM service interface | `lib/services/llm/llm_service.dart` |
| Database schema | `lib/data/database/database.dart` |
| Expression pixel data | `lib/features/face/expression.dart` |
| App theme (dark purple) | `lib/core/theme.dart` |
| Expression parsing utils | `lib/core/utils.dart` |
| Chat orchestration | `lib/providers/providers.dart` → `ChatController` |

## Platform Notes

- Port conflicts: if `flutter run` fails on web, kill dart processes (`Stop-Process -Name dartvm -Force` in PowerShell) or change port in `aiface_run.bat`
- `dart:html` / bash `.bat` issues: run the `.bat` via `cmd.exe /c`, not Git Bash
- After adding a new package, run `flutter pub get` before `flutter run`

# Bisho IDE - Local Web Engine (Phase 1)

This update adds a local WebView-based engine dispatcher for:
- HTML/HTM project preview using the selected SAF project folder.
- JavaScript execution for standalone `.js`, `.mjs`, and `.cjs` files, with a basic console output panel.
- CSS preview in a sample page.
- SVG preview.
- JSON text viewing.

No account, hosting, API key, or remote build service is used for these preview/run features.

Important limitations:
- TypeScript is not compiled yet. It needs a local TypeScript transpiler/compiler bundle.
- JavaScript is executed as a classic script. ES module imports and Node.js APIs are not provided.
- HTML preview loads a local copied project tree. Browser security restrictions can affect some file:// features.
- This phase does not add Python, JVM, LLVM, PHP, Go, Rust, or Flutter execution engines.
- Flutter/Dart app execution still requires Flutter SDK and Android build tooling.

Changed/added files:
- lib/main.dart
- lib/core/services/language_engine_manager.dart
- lib/web_code_runner_screen.dart

The existing SAF service and project file structure are retained.

Build/test note:
The archive has not been compiled with Flutter in this environment. Open it in Klencod and run `flutter pub get`, then build an APK. Report the first compiler/build error if any.

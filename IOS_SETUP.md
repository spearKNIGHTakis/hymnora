# iPhone and iPad support

The official Flutter iOS scaffold has been added for `com.pcg.hymnora`, with display name Hymnals, iOS 15.0 minimum, phone/tablet orientations, background audio capability and the approved app logo in the required icon sizes. It shares the same Dart features, Supabase content, local favourites, downloads and worship sets as Android.

## Build on a Mac

1. Install the matching Flutter SDK, Xcode with the iOS SDK, and native dependency tooling required by Flutter (`flutter doctor -v`). Complete Xcode setup and licensing yourself.
2. Run `flutter pub get`. The generated project uses Flutter's Swift Package Manager integration; install CocoaPods as well if Flutter reports any plugin fallback requires it.
3. Run `flutter run -d <ios-simulator-id> --dart-define-from-file=env.json` and test portrait, landscape, larger text and iPad sizes.
4. Open `ios/Runner.xcworkspace` in Xcode. Select your own Apple signing team under Runner -> Signing & Capabilities. Confirm the bundle identifier is available in your Apple account; change it if needed.
5. On a physical iPhone, test streaming, downloads/offline playback, audio interruptions, background playback, lock-screen/headset controls and safe-area gestures. UIBackgroundModes contains only audio; HTTPS Supabase needs no broad transport-security exception.
6. For TestFlight/App Store distribution, use your Apple Developer account and provisioning, then run `flutter build ipa --release --dart-define-from-file=env.json` and upload through App Store Connect.

## Verification limits

The unsigned iOS Simulator build passed on a hosted macOS runner on 31 October 2026 for commit `da2d2f682d9f6aba081467bc9ea3fdaf93278945`: [successful GitHub Actions run](https://github.com/spearKNIGHTakis/hymnora/actions/runs/41197863178). Xcode compiled `build/ios/iphonesimulator/Runner.app`. This verifies native compilation; the app has not been launched in a simulator or tested on a physical iPhone/iPad. No signed IPA was produced. Apple signing and physical-device audio testing remain before an iOS release.

Official references: https://docs.flutter.dev/platform-integration/ios/setup and https://docs.flutter.dev/deployment/ios . Background audio setup: https://pub.dev/packages/just_audio_background .

## Without a Mac

A GitHub Actions compile workflow is prepared at `.github/workflows/ios-build.yml`. Pushing the prepared `codex/hymnora-studio-player` branch triggers the compile check. Manual dispatch becomes available once the workflow is present on the repository default branch. It uses a standard hosted macOS runner and the exact Flutter 3.47.8 SDK commit verified against the official release tag. It compiles an unsigned simulator app without Apple credentials; this checks native compilation and is not an installable iPhone IPA or App Store release. The first cloud compile completed successfully; see the verification result above. It deliberately does not publish build artifacts or expose backend credentials.

With owner authorization, the app source and extracted hymn catalogue were pushed to the public `codex/hymnora-studio-player` branch. Original source PDFs/images, private SQL setup and environment files are excluded from Git. Apple Developer membership and signing are still needed for TestFlight/App Store distribution; a cloud build service can run those steps once you have an account.

GitHub runner reference: https://docs.github.com/en/actions/reference/runners/github-hosted-runners .

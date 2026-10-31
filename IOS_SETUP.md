# iPhone and iPad support

The official Flutter iOS scaffold has been added for `com.pcg.hymnora`, with display name Hymnora, iOS 15.0 minimum, phone/tablet orientations, background audio capability and the approved app logo in the required icon sizes. It shares the same Dart features, Supabase content, local favourites, downloads and worship sets as Android.

## Build on a Mac

1. Install the matching Flutter SDK, Xcode with the iOS SDK, and native dependency tooling required by Flutter (`flutter doctor -v`). Complete Xcode setup and licensing yourself.
2. Run `flutter pub get`. The generated project uses Flutter's Swift Package Manager integration; install CocoaPods as well if Flutter reports any plugin fallback requires it.
3. Run `flutter run -d <ios-simulator-id> --dart-define-from-file=env.json` and test portrait, landscape, larger text and iPad sizes.
4. Open `ios/Runner.xcworkspace` in Xcode. Select your own Apple signing team under Runner -> Signing & Capabilities. Confirm the bundle identifier is available in your Apple account; change it if needed.
5. On a physical iPhone, test streaming, downloads/offline playback, audio interruptions, background playback, lock-screen/headset controls and safe-area gestures. UIBackgroundModes contains only audio; HTTPS Supabase needs no broad transport-security exception.
6. For TestFlight/App Store distribution, use your Apple Developer account and provisioning, then run `flutter build ipa --release --dart-define-from-file=env.json` and upload through App Store Connect.

## Verification limits

This Windows workstation cannot run Xcode, the iOS simulator or an IPA build. Adding the scaffold and passing cross-platform widget tests does not establish native iOS build success or physical-device audio behaviour. No signing team, credentials or Apple account were invented. Do not advertise an available iOS release until a Mac build and device testing pass.

Official references: https://docs.flutter.dev/platform-integration/ios/setup and https://docs.flutter.dev/deployment/ios . Background audio setup: https://pub.dev/packages/just_audio_background .

## Without a Mac

A GitHub Actions compile workflow is prepared at `.github/workflows/ios-build.yml`. Pushing the prepared `codex/hymnora-studio-player` branch triggers the compile check. Manual dispatch becomes available once the workflow is present on the repository default branch. It uses a standard hosted macOS runner and the exact Flutter 3.47.8 SDK commit verified against the official release tag. It compiles an unsigned simulator app without Apple credentials; this checks native compilation and is not an installable iPhone IPA or App Store release. The workflow has not yet been run. It deliberately does not publish build artifacts or expose backend credentials.

Your repository is public. Pushing this branch would publish the extracted hymn catalogue along with the app source, so that publication needs your explicit decision. Original source PDFs/images, private SQL setup and environment files are excluded from Git. Apple Developer membership and signing are still needed for TestFlight/App Store distribution; a cloud build service can run those steps once you have an account.

GitHub runner reference: https://docs.github.com/en/actions/reference/runners/github-hosted-runners .

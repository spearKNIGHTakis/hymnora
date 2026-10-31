# Hymnora 1.1

Flutter hymn app with English and Twi catalogues, lyrics search, audio, favourites, downloads and worship sets. Both books display PH numbers with explicit language labels; matching numbers are not translation equivalents.

## Features

- 850 Twi and 972 English catalogue entries, offline text, number/title/lyrics search, language filter and Twi character matching.
- Daily hymn, recent listening, favourites, saved reading size and language preferences.
- Full-screen Player/Lyrics view, recording types (male solo, female solo, choir, congregation), per-language voice preferences, download progress/cancel/retry/removal.
- Background audio and Android media notification integration, speed, repeat, A–B practice and timed verse highlighting/repetition when admin timing markers are supplied.
- Worship sets: create, rename, reorder, repeated hymns, download recordings and play available recordings as a queue.
- Subtle playback animation respects reduced motion. Public source viewing and source image assets are removed from the app bundle.
- Published admin edits override bundled content. Unpublishing hides entries on catalogue refresh; the visibility manifest is cached for offline use.

## iPhone and iPad

The iOS project is prepared with background audio and app icons. See IOS_SETUP.md for Mac/cloud builds and Apple signing. An iOS release has not been compiled or device-tested yet.

## Studio

Production admin dashboard: https://hymnora-studio-admin.vercel.app

Admin source is in `admin/`; database migration is in `supabase/migrations/001_studio.sql`. The private deployed dashboard uses Supabase Auth and server-side membership. See `admin/README.md` for import, private PDF proofreading, publishing, recordings and history restore.

Your owner SQL setup has been applied. Sign in using the existing Supabase Auth account `iddrisusofianu284@gmail.com`. Never share passwords or service-role keys.

## Run

```sh
flutter pub get
flutter run --dart-define-from-file=env.json
flutter test
flutter analyze
flutter build apk --release --dart-define-from-file=env.json
```

`env.json` is ignored and contains the public Supabase URL/anon key only. Android APK: `build/app/outputs/flutter-apk/app-release.apk`. The release currently uses the development signing key; configure production signing for a Play Store submission.

## Content and offline limits

The supplied English PDF is a Philadelphia Presbyterian edition, separate from the PCG Twi book. Extracted lyrics require proofreading; see `CATALOGUE_REVIEW.md`. The 29 source-only English entries still need transcription. Original PDFs are private admin reference material and are not in the public app.

Catalogue text works offline. Hosted metadata, lyrics and recording lists are cached after loading. Audio must be downloaded before offline playback. Offline devices and previously downloaded files cannot receive immediate unpublishing updates. Android is the app release target; Studio is a separate responsive web dashboard.

## Verification

All 38 Flutter tests pass, including eight Android/iOS widget configurations across small phones, large text, landscape and iPad layouts with safe-area insets. See RESPONSIVENESS.md. The suite also covers playback, practice loops, queue advancement, worship-set persistence, preferences, downloads, publication overrides and cached hiding. Studio tests execute its migration in PostgreSQL (PGlite), including anonymous/listener write denial, storage policy guards, reviewed publication, draft isolation and revision conflicts. See `admin/QA.md` for browser checks and runtime verification limits.

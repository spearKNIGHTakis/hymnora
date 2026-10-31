# Hymnora 1.1 — review branch

## Included

Private Studio administration, draft/review/publication workflow, version restore, recording upload/type/performer/timing metadata, private PDF proofreading, PH numbering with language labels, full-screen player, practice controls, Android background media integration, worship sets, saved voice preferences and reduced-motion playback animation. Public source viewing is removed.

## Validated

38 Flutter tests passed; Flutter analyzer clean; Android release build succeeded. Four Studio/PostgreSQL tests passed, responsive desktop/mobile UI checked. Live Supabase migration responded with anonymous admin false and private draft reads denied.

## Content and account follow-up

Owner sign-in verified. Imported all 1,822 entries as private drafts and uploaded private English and Twi source references. The Twi reference was reconstructed from 442 preserved page images because the original cached attachment expired. Supplied catalogue text needs review; 29 English entries still need transcription. Recordings and optional verse timings must be uploaded by the administrator. Physical-device background/lock-screen testing and production signing remain before Play Store release.

## Repository

With owner authorization, the app source and extracted hymn catalogue were pushed to the public `codex/hymnora-studio-player` branch at https://github.com/spearKNIGHTakis/hymnora. Private source PDFs/images, env.json, owner SQL and local upload state are excluded. The branch is available for review; it has not been merged into main.

The admin dashboard is hosted on Vercel at https://hymnora-studio-admin.vercel.app. Deployment reported READY and the hosted sign-in page and static assets were verified. Drafts and source PDFs remain in private Supabase storage. See admin/VERCEL.md for redeployment.


## Responsive layouts and iOS compilation

38 Flutter tests passed, including small phone, large-text, landscape and tablet checks under Android/iOS settings with safe areas. Fixed constrained player and empty-state layouts; analyzer clean; Android release APK rebuilt with the approved logo. Added an iOS 15+ target, background audio, iPhone/iPad orientations and icon set. The [cloud iOS Simulator build](https://github.com/spearKNIGHTakis/hymnora/actions/runs/41197863178) passed on macOS on 31 October 2026 for commit `da2d2f6`, producing an unsigned simulator app. Simulator runtime checks and physical-device testing remain pending. An Apple Developer account and signing are still required for TestFlight/App Store release; no signed IPA was produced.

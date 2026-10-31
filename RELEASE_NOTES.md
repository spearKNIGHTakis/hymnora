# Hymnora 1.1 — review branch

## Included

Private Studio administration, draft/review/publication workflow, version restore, recording upload/type/performer/timing metadata, private PDF proofreading, PH numbering with language labels, full-screen player, practice controls, Android background media integration, worship sets, saved voice preferences and reduced-motion playback animation. Public source viewing is removed.

## Validated

30 Flutter tests passed; Flutter analyzer clean; Android release build succeeded. Four Studio/PostgreSQL tests passed, responsive desktop/mobile UI checked. Live Supabase migration responded with anonymous admin false and private draft reads denied.

## Content and account follow-up

Owner sign-in verified. Imported all 1,822 entries as private drafts and uploaded private English and Twi source references. The Twi reference was reconstructed from 442 preserved page images because the original cached attachment expired. Supplied catalogue text needs review; 29 English entries still need transcription. Recordings and optional verse timings must be uploaded by the administrator. Physical-device background/lock-screen testing and production signing remain before Play Store release.

## Repository

Remote already matches https://github.com/spearKNIGHTakis/hymnora.git. Changes are prepared locally on codex/hymnora-studio-player. Private source images, env.json, owner SQL and local upload state are excluded. No public GitHub push has been performed.

The admin dashboard is hosted on Vercel at https://hymnora-studio-admin.vercel.app. Deployment reported READY and the hosted sign-in page and static assets were verified. Drafts and source PDFs remain in private Supabase storage. See admin/VERCEL.md for redeployment.

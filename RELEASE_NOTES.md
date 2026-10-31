# Hymnora 1.1 — review branch

## Included

Private Studio administration, draft/review/publication workflow, version restore, recording upload/type/performer/timing metadata, private PDF proofreading, PH numbering with language labels, full-screen player, practice controls, Android background media integration, worship sets, saved voice preferences and reduced-motion playback animation. Public source viewing is removed.

## Validated

30 Flutter tests passed; Flutter analyzer clean; Android release build succeeded. Four Studio/PostgreSQL tests passed, responsive desktop/mobile UI checked. Live Supabase migration responded with anonymous admin false and private draft reads denied.

## Content and account follow-up

Sign in to Studio with the owner's Supabase Auth account. Import assets/data/hymns.json as private drafts, then privately upload the two source PDFs for proofreading. Supplied catalogue text needs review; 29 English entries still need transcription. Recordings and optional verse timings must be uploaded by the administrator. Physical-device background/lock-screen testing and production signing remain before Play Store release.

## Repository

Remote already matches https://github.com/spearKNIGHTakis/hymnora.git. Changes are prepared locally on codex/hymnora-studio-player. Private source images, env.json, owner SQL and local upload state are excluded. No public GitHub push has been performed.

Private Sites publication is pending because its hosting Git server repeatedly resets the connection. The dashboard is usable locally at http://127.0.0.1:5173/ while the development server is running.

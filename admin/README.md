# Hymnora Studio

Private administration dashboard for the Hymnora Android app. Supabase Auth plus server-side admin membership controls every mutation. No service-role key is shipped.

## Use

Sign in with your existing Supabase Auth account. The owner setup script has granted `iddrisusofianu284@gmail.com` membership. Never put a password in source files.

1. Import catalogue: choose `C:/Users/offic/hymnora/assets/data/hymns.json`. Entries become private, unreviewed drafts. Existing drafts are preserved; import can resume.
2. Select a hymn. Source tab lets you upload the matching original English or Twi PDF into private storage and open a temporary signed preview.
3. Correct title, PH number, language, lyrics and stanza order. Check proofreading, send for review, then publish. Matching PH numbers in different languages do not imply the books are translations.
4. Recordings tab: choose an audio file (maximum 50 MB), male solo/female solo/choir/congregation and performer. Optional timing markers use `1=0`, `2=34.5` on separate lines. Uploads are private. Preview and explicitly publish after the hymn is published.
5. Unpublish hides content from refreshed app catalogues. History restores a previous version as a draft. Previously downloaded recordings cannot be recalled.

Catalogue text is extracted draft content. Proofread before publishing. The 29 source-only English entries need lyrics entered manually.

## Development

`npm ci`, `npm run dev`, `npm test`, `npm run build`.

`?preview` is a development-only interface sandbox. It uses labelled browser-local samples, cannot upload to the backend, and is eliminated from production builds.

The applied database migration is `backend/001_studio.sql`; local owner setup is excluded from source hosting. PDFs, imported catalogues and credentials are not deployed as static assets. `.openai/hosting.json` retains the existing private Sites project identity.

## Verification

See QA.md for browser checks, database authorization tests, design fidelity and remaining device/account checks.

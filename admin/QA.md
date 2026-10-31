# Verification — 31 October 2026

## Behaviour

Flutter: 30 regression tests passed; analyzer found no issues. Android release APK compiled successfully (56.2 MiB); archive inspection confirmed zero source-image entries and the bundled catalogue present. Tests cover audio load/resume/failure, A–B loop reentrancy, speed/repeat, queue completion, worship-set persistence/reordering, downloads/cancellation/integrity, saved preferences, publication overrides and cached unpublishing.

Studio: four Node tests passed, including the full SQL migration executed in PostgreSQL/PGlite. Verified anonymous RPC denial, authenticated listener denial, restrictive storage guards despite a broad existing policy, private drafts, reviewed publication, editing without changing live lyrics, optimistic revision conflicts, recording publication prerequisites and unpublishing.

Live backend after owner applied SQL: membership RPC returned false anonymously; visibility API returned 200; private draft read returned 401. This verifies deployment and anonymous boundaries, not the owner's signed-in session.

Browser flow: development sandbox -> edit stanza -> save draft -> mark proofread -> review -> publish. Verified rendered success/status, recording upload form/type choices, English filtering, import dialog and normal login. No console errors/warnings observed. Browser plugin not listed; used the provided CUA in-app browser. Local samples are explicitly labelled and excluded from production.

Desktop 1440×1000 and mobile 390×844 checked. Mobile header visibility mismatch was corrected and recaptured. Temporary viewport reset after testing. Screenshots are in checkout-local `qa/` (not hosted).

## Fidelity ledger

| Check | Result |
|---|---|
| Cream canvas / navy sidebar and buttons | Matches concept tokens #FFF8E7 / #183B56 |
| Sidebar, table, editor hierarchy | 230px sidebar, 390px desktop drawer, 32px gutters retained |
| Typography and controls | System sans-serif, 32px main title, 14px controls, restrained line icons |
| Table and selection | Language/status columns, pale blue selected row, explicit PH+language |
| Editing forms | Stanza order/kind, native text fields, fixed save/review footer |
| Responsive / motion | Mobile navigation and full-width editor; reduced-motion CSS and Flutter animation checks |

Concept and final screenshots were opened side by side with local image inspection. Intentional deviations: no bulk checkboxes or decorative sample dates; production uses real data. Source tab, proofreading checkbox, history restore and timing fields implement actual workflows. Upload controls live under Recordings to keep the lyrics view focused. The preview-only banner explains that QA samples are browser-local; production has no demo branch.

## Remaining runtime/content checks

The owner must sign in to verify their account and do the first real private PDF/audio upload. No credentials were requested or invented. Test Android background/lock-screen controls on a physical device; release compilation verifies integration, not OEM behaviour. Extracted hymn text still needs proofreading, and 29 English entries require transcription. Recordings and timing markers must be supplied by the administrator. Release signing is currently the development key.

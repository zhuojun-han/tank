# Historical one-off acceptance scripts

These scripts target retired UI and are intentionally excluded from current regression entrypoints. They are retained as evidence; do not run them against the current app.

- `po4-browser.mjs`: former sample chooser, direction selector, checkbox and JSON download. Current UI coverage: `unified-photo-rotation.mjs`, `po4-integration-history.mjs`; color decisions: `po4-analysis.test.ts` / `color-analysis.test.ts`. Dataset evaluation uses project manifests separately.
- `independent-judgments.mjs`: depended on generated cached NO3 output and the retired PO4 chooser. Independent confidence gates are covered by `color-analysis.test.ts`; editable null-interpolation records are covered by the active photo review tests.

Historical screenshots/reports remain in `artifacts/`. No archived script is counted as a passing current test.

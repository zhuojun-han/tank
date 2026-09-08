# Corrected A1 light semi-realistic animation study

## Corrected anchor

This round uses `../shortlist/selected-clownfish-A1-reference.png` as the only identity anchor. It is the small-eye, calm-expression A1 fish selected by the user from the reef comparison image. The previously saved big-eye smiling fish is explicitly not the selected A1.

## Variants

- R1 refined original: closest to the selected A1, with a smaller natural mouth, refined eye reflection and fin edges.
- R2 gentle charm: body shortened slightly and eye enlarged only subtly.
- R3 swim motion: preserves A1 identity with a subtle active swimming posture.
- R4 underwater cinematic: adds restrained cyan environmental reflection and more natural living-fish material.

All prompts lock the following constraints: restrained eye scale, compact rounded anatomy, right-facing full-body profile, exactly three white bands, small non-human mouth, living fish skin, no exaggerated smile, no toy material, and no extra scene elements.

## Asset status

- `comparison-in-selected-reef.png` is the main visual-selection board.
- R2, R3 and R4 have separately validated alpha candidates with the `-alpha.png` suffix.
- The generator did not produce a valid alpha channel for R1 after two extraction attempts. `R1-refined-original.png` remains a preview candidate only. If R1 is selected, regenerate or extract the final production sprite before App integration.
- None of these assets has replaced the website or Flutter App artwork.

Generated with the built-in ImageGen mode.

# Release readiness

**Status:** release-readiness preparation, 13 November 2026.
**Baseline:** branch `main`, commit `b1579db`, working tree clean, QA evidence
and test logs retained. Nothing in this phase changes the baseline.

This document is the gate list for turning the accepted release candidate into
a production release. It does not claim the game is production-ready.

## 1. Gate summary

| # | Gate | State | Evidence | Owner action |
|---|---|---|---|---|
| 1 | Rules, validation, save, layout | **PASS** | 126 checks, 0 failed | — |
| 2 | Solver parity, both directions | **PASS** | 154 checks + 30-level transcript replay | — |
| 3 | 30-level gameplay through the game | **PASS (automated)** | 153 flow checks, 30/30 wins | — |
| 4 | Manual playthrough | **OPEN** | 1/30 by hand; depth agreed 17 Nov (levels 1–10 + one 5-colour + one 6-colour), not yet executed | execute the agreed subset |
| 5 | Presentation tickets | **PASS** | 21 accepted tickets, `docs/evidence/rc-*.png` | — |
| 6 | Visual polish (QA-05) | **PASS (type scale)** | owner approved the type scale only; applied, evidence re-captured 17 Nov | other items stay post-1.0 |
| 7 | Palette separation (QA-01) | **ACCEPTED EXCEPTION** | 13/30 in the 12–14.9 band, none forbidden; re-verified by `tools/solver/audit_palette.py` | revisit in 1.1 |
| 8 | Post-win undo (QA-03) | **RESOLVED** | Policy A; `rules-v1` §7.1 decision record added; shipped behaviour already sealed | — |
| 9 | Minimum SDK (QA-04) | **RECORDED, NOT APPLIED** | B8 = min 24 / target 35 recorded, but Godot rejects the override without Gradle; artifact ships 24/36 | choose ratification or the Gradle path (§0.1 of `owner-decisions.md`) |
| 10 | Levels 3–5 empty-vessel lesson | **ACCEPTED EXCEPTION** | re-verified: 6/7/7 with empty-tube pours forbidden | revisit in 1.1 |
| 11 | Audio audition (QA-02) | **BLOCKED (human)** | no listening pass yet; owner has agreed to listen | listen and sign off |
| 12 | Android static configuration | **PASS** | portrait, version 2, icons, gating, arm64 | — |
| 13 | Physical device validation | **BLOCKED** | S23 Ultra agreed but not connected; `adb devices` empty | connect the device |
| 14 | Production signing (M10-03) | **BLOCKED** | no keystore in this environment; RC is debuggable/debug-signed | provide key + approval |
| 15 | Publishing | **BLOCKED** | owner boundary | approve after 11–14 |

## 2. What is verified now

- `tools/test.ps1` — rules 126, parity 154, flow 153, game-moves 30, all exit 0.
- `builds/sort-master-rc.apk` — 27.18 MB, `com.prismgarden.sortmaster`,
  versionCode 2, portrait (`screenOrientation=1`), arm64-v8a, adaptive icon,
  no debug/test assets, legal texts included.
- Debug and RC builds are distinct: `dev_build` vs `release_build`; the F1
  overlay exists only in the debug build.
- The RC is a **debug build**: `android:debuggable=true`, signed with Godot’s
  public debug key. It is an internal test artifact, not a release artifact.

## 3. What is not verified

- Any physical-device behaviour (touch, safe areas, frame time, thermals,
  audio, launcher icon).
- Audio tone; no human has listened to the six sounds.
- A production signature; no keystore exists in this environment.
- 30/30 manual completion; the flow harness is not a manual pass.
- Edge-to-edge behaviour implied by targetSdk 36.

## 4. Release sequence (only after decisions)

1. Apply the approved decisions (palette exceptions or re-authoring, post-win
   policy, SDK levels, levels 3–5).
2. Re-run `tools/test.ps1`; rebuild the RC with `tools/build_rc.ps1`; verify
   package, version, orientation and gating.
3. Owner signs the release build per `docs/release-signing.md`; verify the
   certificate and `debuggable=false`.
4. Execute `docs/device-validation.md` on the S23 Ultra; fix failures and
   retest.
5. Execute `docs/audio-audition.md`; fix any rejected sound.
6. Owner approves publishing.

## 5. Invariants for this phase

- Do not change the 30 frozen levels without explicit approval.
- Do not change the palette policy, rules, minimum SDK or architecture without
  approval.
- Do not generate, request, expose or commit signing credentials.
- Do not mark a ticket Done without evidence and a retest.
- Do not rewrite or discard the `b1579db` baseline.

## 6. Related documents

- `docs/owner-decisions.md` — the four pending decisions with evidence.
- `docs/device-validation.md` — S23 Ultra matrix and evidence template.
- `docs/audio-audition.md` — human listening checklist.
- `docs/release-signing.md` — secure signing procedure.
- `docs/test-plan.md`, `docs/palette-matrix.md`, `docs/release-candidate.md`.

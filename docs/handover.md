# Project handover — Sort Master — Prism Garden

**Handover date:** 17 November 2026
**Repository:** `C:\Users\Asus\source\repos\sort-master`
**Branch:** `main`
**HEAD:** `c97798b` (documentation); QA baseline `b1579db` is preserved as its parent
**Working tree:** clean
**Board:** FlowQuery `brd_BGCJBCQX24Q0JHZGJ6D57DZZ5M`
**Status:** release candidate, QA-passed core, **not production-ready**

This file is written for a new agent/harness taking over. Read it first, then
the documents in §2, then the board. Do not rely on this summary alone.

---

## 1. End goal

Take the accepted release candidate to a **defensible, production-ready
release**:

1. Record and apply the four owner decisions (palette, post-win undo, minimum
   SDK, levels 3–5) — or keep the documented exceptions.
2. Produce a **release-signed** APK (owner keystore; the current RC is a
   debuggable debug build) and verify identity, version, orientation, SDK,
   ABI, signing and contents.
3. Execute the **S23 Ultra** device pass with evidence and fix failures.
4. Execute the **human audio audition** and fix rejected sounds.
5. Decide and execute the manual-play depth (currently 1/30 by hand).
6. Apply only approved QA-05 polish (type scale is the only 1.0 candidate).
7. Reconcile FlowQuery honestly: Done only with evidence; blocked tickets keep
   their blocker.
8. Hand the owner a signed, device-validated, audio-checked artifact and a
   clean board.

Do **not** call the game production-ready until 2–4 are genuinely complete.
Never invent device, audio or signing results.

---

## 2. Read-first order

Repository docs:

1. `README.md`
2. `docs/release-readiness.md` — the 15-gate table and release sequence
3. `docs/owner-decisions.md` — QA-01, QA-03, QA-04, levels 3–5 with evidence
4. `docs/device-validation.md` — 40-check S23 matrix and template
5. `docs/audio-audition.md` — human checklist
6. `docs/release-signing.md` — secure signing procedure
7. `docs/test-plan.md` — suites, device matrix, current results
8. `docs/palette-matrix.md` — colour/symbol contrast and the level-pair gap
9. `docs/rendering.md` — backdrop, glass, board layout
10. `docs/release-candidate.md` — artifact, presets, verification
11. `docs/credits-and-licences.md` — provenance
12. `docs/rules-v1.md` and `docs/levels.md` — frozen rules and level catalogue
13. `docs/deferred-work.md` — what is deliberately not done

Master plan (source of truth for the product, outside the repo):
`C:\Users\Asus\source\repos\Sort Master — Prism Garden\SORT_MASTER_MASTER_PRODUCTION_PLAN\`
(start with `00_MASTER_README.md`, then `10_QA_AND_ACCEPTANCE.md`).

Tip: the plan folder path contains an em dash; some shell scanners reject it.
Use the file-read tool or quoted paths.

---

## 3. Snapshot

| Item | Value |
|---|---|
| Engine | Godot 4.7.2 stable, GDScript |
| Renderer | mobile, ETC2/ASTC setting, arm64-v8a |
| Design | 1080 × 1920 portrait, `canvas_items` / `expand` |
| Package | `com.prismgarden.sortmaster` |
| Version | 0.1.0, versionCode 2 |
| Levels | 30, solver-verified, frozen |
| Rules | `rules-v1`, frozen |
| Tests | rules 126, parity 154, flow 153, game-moves 30 — all pass |
| RC APK | `builds/sort-master-rc.apk`, 27.18 MB, **debuggable debug build, debug-signed** |
| Debug APK | `builds/sort-master.apk`, 27.21 MB, F1 overlay |
| Board | 47 Backlog / 0 Todo / 1 In Progress / 4 Review / 24 Done |
| Manual play | 1/30 by hand; the rest is automated flow coverage |
| Device | **not tested** |
| Audio | **not auditioned** |
| Signing | **no production keystore** |

### Architecture map

| Area | Files |
|---|---|
| Rules/domain | `godot/scripts/domain/puzzle_state.gd`, `level_validator.gd`, `progress_store.gd` |
| Board 3D | `godot/scripts/presentation/board_3d.gd`, `board_layout.gd`, `garden_backdrop.gd`, `vessel_builder.gd`, `vessel_mesh.gd` |
| Shaders | `godot/assets/shaders/garden_3d.gdshader`, `glass.gdshader` |
| UI | `godot/scripts/ui/main.gd` (all screens), `palette.gd`, `ui_kit.gd`, `icon_button.gd`, `icon_glyphs.gd`, `level_tile.gd`, `emblem.gd`, `backdrop.gd` |
| Audio | `godot/scripts/audio/audio_director.gd`, `godot/assets/audio/*.wav` |
| Debug overlay | `godot/scripts/debug/debug_overlay.gd` (excluded from release) |
| Tests | `godot/tests/test_rules.gd`, `parity.gd`, `test_flow.gd`, `solutions.json`, `capture.gd`, `capture_qa.gd` |
| Tools | `tools/test.ps1`, `build_debug.ps1`, `build_rc.ps1`, `_build_lib.ps1`, `make_*.ps1`, `solver/*.py` |
| Legal | `licences/`, `godot/assets/legal/` |
| Evidence | `docs/evidence/` |

---

## 4. FlowQuery protocol

**API base:** `https://flowquery.workstack.workers.dev/api/v1/agent`
**Board:** `brd_BGCJBCQX24Q0JHZGJ6D57DZZ5M`
**Token:** `C:\Users\Asus\source\repos\FlowQuery\.agent-token`

Never print, log or commit the token. If it is missing, ask the owner.

### Read

```powershell
$Base = 'https://flowquery.workstack.workers.dev/api/v1/agent'
$T = (Get-Content -LiteralPath 'C:\Users\Asus\source\repos\FlowQuery\.agent-token' -Raw).Trim()
$H = @{ Authorization = "Bearer $T" }
$board = Invoke-RestMethod -Uri "$Base/board" -Headers $H
$review = Invoke-RestMethod -Uri "$Base/tasks?status=review&limit=100" -Headers $H
$task = (Invoke-RestMethod -Uri "$Base/tasks/<id>" -Headers $H).task
```

### Comment / move

```powershell
$body = @{ body = 'evidence...' } | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$Base/tasks/<id>/comments" -Headers $H -Method Post -Body $body

$move = @{ status = 'done'; position = 0; expectedVersion = $task.version } | ConvertTo-Json -Compress
Invoke-RestMethod -Uri "$Base/tasks/<id>/move" -Headers $H -Method Post -Body $move
```

Columns: `backlog → todo → in_progress → review → done`. Move through the
chain if a direct move is rejected. Create defects with
`POST $Base/tasks` and `{title, description, status:'backlog'}`.

### Board rules

- **Done only with acceptance evidence and a retest.** Never close to improve
  counts.
- Blocked tickets identify the blocker (device, owner, human, credentials).
- Record owner decisions before implementing them.
- New defects get reproduction steps, severity and evidence.
- Backlog is not an automatic execution queue; respect dependencies.

### Current tickets that matter

| ID | What |
|---|---|
| `tsk_C4W8BK0W2M0A5CJD84W85MHQP0` | QA-01 palette exceptions (owner) |
| `tsk_90CBCN83A4GW0FTMR5MEQZYVMR` | QA-02 audio audition (human) |
| `tsk_78ZANFYSR86TYXETE0NZDY9BN8` | QA-03 post-win undo policy (owner) |
| `tsk_N48EE463CZ517T01N505PJYYGC` | QA-04 minimum SDK (owner) |
| `tsk_Z06M56P31H0NV4M2QRJ66KV3R0` | QA-05 visual polish (backlog) |
| `tsk_WJ251CK875T2DQ7ZXXTQSC5GDG` | Levels 3–5 lesson (owner, in Backlog) |
| `tsk_BEZK6BD8TZM82866Q8EM99RQMM` | M8-06 manual play (In Progress) |
| `tsk_B91X0J0Q6X5G0WZ8HMMH4S6490` | Android presets (Review; SDK/signing blocked) |
| `tsk_9R7WT4DE7HT3HNV28K87J0R1WR` | Levels 1–2 (Review; device blocked) |
| `tsk_SG56JRHDKYAVFJVHS3ZXE1KHGR` | Audio licences (Review; audition blocked) |
| `tsk_1DSZE4YETTQZ2VNDQ4RV8XHS3W` | Palette (Review; QA-01 + device) |

---

## 5. Owner gates — do not cross without explicit approval

| Change | Approval needed |
|---|---|
| Frozen 30 levels | explicit |
| Palette policy / re-authoring | explicit |
| Rules (`rules-v1`) | explicit |
| Minimum/target SDK | explicit |
| Architecture/scope | explicit |
| Material visual/audio design | explicit |
| Generating/handling signing keys | explicit |
| Publishing/distributing | explicit |

Never create a keystore, request passwords in chat, print secrets, or commit
`*.jks`, `*.keystore`, `export_credentials.cfg`.

---

## 6. Verification commands

```powershell
$env:GODOT = 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'
powershell -ExecutionPolicy Bypass -File tools\test.ps1      # 126 / 154 / 153 / 30
powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1
powershell -ExecutionPolicy Bypass -File tools\build_rc.ps1  # asserts package/version/portrait
```

APK checks:

```powershell
aapt2 dump badging builds\sort-master-rc.apk
aapt2 dump xmltree --file AndroidManifest.xml builds\sort-master-rc.apk
apksigner verify --verbose --print-certs builds\sort-master-rc.apk
```

Expected now: package `com.prismgarden.sortmaster`, code 2, portrait,
`debuggable=true`, Godot debug key, no `scripts/debug`/`tests/` in the RC.
A production build must show `debuggable=false` and the owner’s certificate.

---

## 7. Invariants

- `rules-v1` and the 30 levels are frozen.
- Single-writer rule: one agent edits at a time; reviewers are read-only.
- No ads, analytics, accounts, network calls or purchases.
- Offline saves only (`user://progress.json`).
- The M8-06 overlay must never appear in a release build.
- Do not rewrite/amend/reset the `b1579db` baseline or discard evidence.
- Do not claim device, audio or signing verification without artifacts.

---

## 8. First ten actions for the new harness

1. Verify `git status` is clean and HEAD is `c97798b`; read §2 docs.
2. Run `tools/test.ps1`; confirm 126 / 154 / 153 / 30.
3. Fetch the board; confirm 47/0/1/4/24 and read QA-01…QA-05.
4. Ask the owner to record the four decisions (use the exact sentences in
   `docs/owner-decisions.md`); do not implement before answers.
5. If signing credentials are provided, follow `docs/release-signing.md` and
   build a `debuggable=false` release; verify the certificate.
6. If the S23 Ultra is available, execute `docs/device-validation.md` from D01;
   record PASS/FAIL/BLOCKED/NOT TESTED with screenshots/logs.
7. Run `docs/audio-audition.md` with a human; fix rejected sounds only.
8. Apply approved decisions; rerun the gate; rebuild; update evidence.
9. Reconcile the board: Done only with evidence; keep blocked tickets blocked.
10. Write one final report with gate status, evidence, remaining blockers.

---

## 9. Definition of done (production)

- All four owner decisions recorded and implemented or explicitly excepted.
- `debuggable=false` release APK signed with the owner’s key; identity, version,
  portrait, SDK and ABI verified; build log and certificate digest archived.
- S23 Ultra checklist complete with evidence; no critical/high failures.
- Audio audition PASS or defects fixed and retested.
- Manual play depth agreed and executed.
- `tools/test.ps1` green; no weakened tests.
- Board accurate; no false Done; working tree clean.
- Owner approval to publish recorded.

Until then the correct classification remains **release candidate**.

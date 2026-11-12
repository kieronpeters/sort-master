# Sort Master — Prism Garden

Water-sort puzzle for Android. Five polished levels, 2.5D presentation
(3D vessels, 2D interface), offline, no ads or monetisation in the prototype.

**Status:** M0 research complete. G1 environment installed and verified.
No game code yet — this repository is the skeleton created by M1-04.

## Toolchain (verified 12 Nov 2026)

| Component | Version | Location |
|---|---|---|
| Godot | 4.7.2 stable | `C:\Tools\Godot\4.7.2` |
| Export templates | 4.7.2 | `%APPDATA%\Godot\export_templates\4.7.2.stable` |
| Temurin JDK | 17.0.21 | `C:\Tools\jdk-17.0.21.9` |
| Android SDK | platform-tools 37.0.1, build-tools 35.0.1, platform 35 | `%LOCALAPPDATA%\Android\Sdk` |
| Blender | 4.5.15 LTS (pinned) | existing install |

Oracle Java 8 remains installed and remains the default `java` on PATH.
Do not change `JAVA_HOME` or PATH to make the toolchain work.

## Layout

```
godot/          Godot project root (open this in the editor)
  scenes/       screens and components
  scripts/      domain (rules), services, presentation, ui
  assets/       3d, 2d, audio, themes
  levels/       data-only level definitions
  tests/        automated tests
art_source/     Blender and Krita sources - outside the Godot project on purpose
tools/          blender build scripts, Python solver
docs/           decision records and milestone reports
licences/       licence evidence for third-party assets
builds/         APK output (git-ignored)
```

`art_source/` sits outside `godot/` so the engine never imports `.blend` files.

## Scope boundaries

- Android first; S23 is the minimum performance target.
- No backend, accounts, cloud saves, analytics, ads or purchases.
- No points, hints or economy in the first five levels.
- Full art and screen production wait for the G2 rendering proof of concept.

## Planning documents

The production plan lives outside this repository, next to it:
`..\Sort Master — Prism Garden\SORT_MASTER_MASTER_PRODUCTION_PLAN\`
(read-only reference; the copy in `docs/` is not maintained).

## Working rules

- One writer per file at a time; coordination happens on the FlowQuery board.
- No commits to shared branches, no pushes, no deploys without owner approval.
- Never commit secrets, keystores or build output.

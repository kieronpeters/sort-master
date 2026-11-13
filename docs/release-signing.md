# Release signing and production build

**Status:** procedure prepared, **not executed**. No production keystore exists
in this environment, and none may be created, requested or committed without
the owner’s explicit authorisation.

The current RC is a **debug build**: `android:debuggable=true`, signed with
Godot’s publicly shipped debug key (`CN=Godot`). It is for internal testing
only and must not be published.

## 1. Owner prerequisites

The owner must provide and approve:

1. a keystore file (`.jks`) and key alias;
2. the store password and key password;
3. the certificate identity to use (organisation/name, validity);
4. where the keystore and passwords will be stored and who holds them;
5. approval to build and sign a release artifact.

Do not send credentials in chat, tickets, commits or logs.

## 2. Secure handling rules

- The keystore and `export_credentials.cfg` are **git-ignored** (`.gitignore`
  already covers `*.keystore`, `*.jks`, `*.p12`, `export_credentials.cfg`).
- Keep the keystore outside the repository, in an encrypted location with a
  tested backup. Losing it means losing the ability to update the app under the
  same identity.
- Prefer Godot’s `export_credentials.cfg` in the user profile, or environment
  variables read by the build shell, over editing the preset.
- Never print the password in a command that is logged. Use a credential file
  or a masked prompt.
- The build scripts must not read or echo the passwords.
- Revoke/rotate only with owner approval; record the certificate SHA-256 in the
  release notes.

## 3. Procedure

### 3.1 Prepare the preset (owner-approved change)

In `godot/export_presets.cfg`, for the release preset only:

```
package/keystore/release="<absolute path outside the repo>"
package/keystore/release_user="<alias>"
package/keystore/release_password="<from credential file>"
```

Do not set `package/keystore/debug` for the release build. Keep the debug
preset separate.

### 3.2 Build

```powershell
# after the owner has configured credentials
& $env:GODOT --headless --path godot --export-release "Android RC" builds\sort-master-release.apk
```

Or extend `tools/build_rc.ps1` with an explicit `-Release` switch that refuses
to run unless the release keystore is configured. The script must keep the
current fallback behaviour for internal test builds and must never silently
substitute the debug key for a requested release build.

### 3.3 Verify the artifact

```powershell
aapt2 dump badging builds\sort-master-release.apk
aapt2 dump xmltree --file AndroidManifest.xml builds\sort-master-release.apk
apksigner verify --verbose --print-certs builds\sort-master-release.apk
zipalign -c 4 builds\sort-master-release.apk
```

Required results:

| Check | Expected |
|---|---|
| Package | `com.prismgarden.sortmaster` |
| Version | 0.1.0, versionCode 2 (bump per release) |
| Orientation | `screenOrientation=1` (portrait) |
| ABI | arm64-v8a |
| min/target SDK | per the approved B8 decision |
| `debuggable` | **false** |
| Signature | release certificate, v2/v3 verified, intended DN/SHA-256 |
| Alignment | `zipalign -c 4` exit 0 |
| Contents | no `scripts/debug`, `tests/`, dev scenes |
| Size | record it; compare with the RC |

Retain `builds/build-release.log`, the badging output, the certificate digest
and the APK SHA-256.

### 3.4 Archive

- Store the signed APK and the build log with the release notes.
- Record the commit hash, version code, certificate SHA-256 and SHA-256 of the
  APK.
- Do not commit the APK, keystore or passwords.

## 4. AAB / Play Store note

The current export is an APK without Gradle. A Play Store AAB requires the
Gradle build path plus Android NDK/CMake, which are not installed. That is a
separate owner-approved task; do not attempt it as part of signing.

## 5. Failure handling

| Symptom | Action |
|---|---|
| “Could not find release keystore” | Stop; the owner has not configured it. Do not fall back to debug for a release artifact. |
| Signature verifies but `debuggable=true` | Wrong export mode; rebuild with `--export-release`. |
| Wrong version code | Bump both presets and the build-script assertion. |
| Wrong orientation | Check `display/window/handheld/orientation=1`; rebuild. |
| Keystore lost | Stop and inform the owner; a new key means a new app identity unless Play App Signing is in use. |

## 6. What the agent will not do

- Generate a keystore or password.
- Ask for credentials in chat.
- Commit or print secrets.
- Publish or distribute the artifact.
- Claim a release build from the current debug-signed RC.

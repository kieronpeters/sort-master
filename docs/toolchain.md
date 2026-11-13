# Development Toolchain Record

**Status:** current as of 13 November 2026. Verified by command output, not by memory.
**Owner of this document:** Noah (environment), reviewed by Alex. Maintained by Bob under the single-writer rule.
**Change policy:** update this file whenever a version changes, with the command output that proves it. A version that is not recorded here is not supported.

---

## 1. Operating system

| Item | Value | How verified |
|---|---|---|
| Edition | Windows 11 Home Single Language | `Get-CimInstance Win32_OperatingSystem` |
| Version | 26H2 | registry `DisplayVersion` |
| Build | 26300.9818 | `BuildNumber` + `UBR` |
| Architecture | x64 | `OSArchitecture` |
| Shell used for all commands | Windows PowerShell 5.1 | `$PSVersionTable` (no PowerShell 7 installed) |

---

## 2. Installed toolchain

| Component | Version | Location | Verification |
|---|---|---|---|
| **Godot** | **4.7.2.stable.official.ed1daf0bf** | `C:\Tools\Godot\4.7.2` | `--version` |
| **Export templates** | **4.7.2.stable** | `%APPDATA%\Godot\export_templates\4.7.2.stable` | `version.txt`; `android_debug.apk` and `android_release.apk` present |
| **Temurin JDK** | **17.0.21+9** (`javac 17.0.21`) | `C:\Tools\jdk-17.0.21.9` | `javac -version` |
| **Android platform-tools** | **37.0.1** (`adb 1.0.41`) | `%LOCALAPPDATA%\Android\Sdk\platform-tools` | `adb version`, `sdkmanager --list_installed` |
| **Android build-tools** | **35.0.1** | `%LOCALAPPDATA%\Android\Sdk\build-tools\35.0.1` | `sdkmanager --list_installed`; `aapt2.exe` present |
| **Android platform** | **android-35** (rev 2.0.0) | `%LOCALAPPDATA%\Android\Sdk\platforms\android-35` | `sdkmanager --list_installed`; `android.jar` present |
| **Android cmdline-tools** | **23.0** | `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest` | `source.properties` |
| **Git** | **2.55.0.windows.3** | `C:\Program Files\Git` | `git --version` |
| **Python** (solver/tooling) | **3.15.0** (3.12.10 also installed) | `%LOCALAPPDATA%\Programs\Python\Python315` | `python -V` |
| **FFmpeg** (media tooling) | **9.0.2** full build | winget package path | `ffmpeg -version` |
| **Blender** | **4.5.15 LTS** (pinned) | `%LOCALAPPDATA%\Programs\BlenderFoundation\Blender-4.5.15` | folder name + `blender --version` |
| **Krita** | 6.0.4 | `C:\Program Files\Krita (x64)` | installer record |
| **Oracle Java 8** | **1.8.0_503** (JRE) | `C:\Program Files\Java\jre1.8.0_503` | `java -version` |

Blender is deliberately pinned. It must not be upgraded mid-project without a decision record; its glTF exporter is part of the asset pipeline.

---

## 3. Environment variables and PATH

| Variable | Scope | Value |
|---|---|---|
| `JAVA_HOME` | User | **not set** |
| `JAVA_HOME` | Machine | **not set** |
| `ANDROID_HOME` | Process | **not set** |
| `ANDROID_SDK_ROOT` | Process | **not set** |
| `PATH` | User | 741 characters, unchanged since before G1 |
| `PATH` | Machine | 787 characters, unchanged since before G1 |

**This is intentional.** Nothing was added to PATH. Godot stores its own paths in editor settings:

| Godot editor setting | Value |
|---|---|
| `export/android/java_sdk_path` | `C:/Tools/jdk-17.0.21.9` |
| `export/android/android_sdk_path` | `C:/Users/Asus/AppData/Local/Android/Sdk` |

Stored in `%APPDATA%\Godot\editor_settings-4.7.tres`, and confirmed to persist after an editor restart.

---

## 4. Java 8 preservation

`java` on PATH still resolves to **Oracle Java 8 (1.8.0_503)** and must continue to do so. JDK 17 is used only:

- by Godot, through the explicit `java_sdk_path` above;
- by `sdkmanager`, through a **session-scoped** `$env:JAVA_HOME` set in the same shell.

Nothing about Java 8 was modified, upgraded or removed.

**Consequence to remember:** running `sdkmanager` in a fresh shell without setting `JAVA_HOME` will fail with `UnsupportedClassVersionError`. That is expected, not a broken install.

---

## 5. Android SDK configuration

Installed packages (from `sdkmanager --list_installed`):

```
build-tools/35.0.1      35.0.1    Android SDK Build-Tools 35.0.1
cmdline-tools/latest    23.0.0    Android SDK Command-line Tools (latest)
platform-tools          37.0.1    Android SDK Platform-Tools
platforms/android-35    2.0.0     Android SDK Platform 35
```

Deliberately **not** installed: Android Studio, the emulator and system images, NDK, CMake, Git LFS. NDK/CMake are only needed if Gradle/AAB builds are ever required, and that decision is not made.

SDK licences were accepted locally during G1 via `sdkmanager --licenses`.

---

## 6. Disk usage and locations

| Item | On disk |
|---|---|
| Godot editor | 172.7 MB |
| Export templates | 1,976.3 MB |
| Temurin JDK 17 | 303.3 MB |
| Android SDK (all packages) | 424.0 MB |
| **Total added by G1** | **~2.87 GB** |
| Free on C: at time of writing | **97.49 GB** |

Installer archives were deleted after verification. The G1 manifest and log remain at `%LOCALAPPDATA%\G1`.

---

## 7. Known warnings and quirks

1. **`sdkmanager` is deprecated.** cmdline-tools v23 prints a warning recommending the new `android` CLI (`android sdk`). `sdkmanager` still works; the documented commands below remain valid. Migrating to `android` is a future decision, not a defect.
2. **Multi-package install only processed the first package.** `sdkmanager --install "a" "b" "c"` installed only `a`. Installing each package separately worked, and `--package_file` worked for a list. Recorded because it would silently produce an incomplete SDK.
3. **Semicolons on the command line.** Passing `"build-tools;35.0.1"` directly to the `.bat` from PowerShell was split into two arguments. Use `--package_file` or install one package at a time.
4. **Exit code noise.** `java -version` and `javac -version` write to stderr; under `$ErrorActionPreference = 'Stop'` that aborts a script. Wrap in `cmd /c "... 2>&1"`.
5. **Godot rewrites `project.godot` on first open** (header comments plus `config/features`). Expected; committed as its own change.

---

## 8. Verified facts vs untested capability

**Verified:**

- every version in §2, by running the binary or reading the tool's own metadata;
- the Godot editor opens, scans the project and renders the Project Manager;
- the Android SDK packages exist at the stated paths with their key binaries (`adb.exe`, `aapt2.exe`, `android.jar`);
- PATH and both `JAVA_HOME` scopes are unchanged from the pre-install snapshot.

**Not verified — do not assume:**

- an actual **Android export** has not been produced. G1's matrix item 8 is unproven until M1-03.
- the device has never been connected: `adb devices` has not been run against the S23 Ultra.
- hardware acceleration, Gradle builds, AAB output and NDK are untested and uninstalled.
- Blender's glTF export path has not been exercised in this project.
- the emulator is not installed and its feasibility is only assessed on paper (`18_ANDROID_TEST_STRATEGY_AND_EMULATOR_FEASIBILITY.md`).

---

## 9. Inspection commands

Copy-paste, read-only. Run in Windows PowerShell 5.1.

```powershell
# OS
Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, OSArchitecture

# Godot + templates
& 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe' --version
Get-Content "$env:APPDATA\Godot\export_templates\4.7.2.stable\version.txt"
Test-Path "$env:APPDATA\Godot\export_templates\4.7.2.stable\android_debug.apk"

# JDK 17 and Java 8 side by side
cmd /c '"C:\Tools\jdk-17.0.21.9\bin\javac.exe" -version 2>&1'
cmd /c '"C:\Program Files\Java\jre1.8.0_503\bin\java.exe" -version 2>&1'
cmd /c "java -version 2>&1"          # must still report 1.8.0_503

# Android SDK
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
$env:JAVA_HOME = 'C:\Tools\jdk-17.0.21.9'      # session only
& "$sdk\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="$sdk" --list_installed
& "$sdk\platform-tools\adb.exe" version
Test-Path "$sdk\build-tools\35.0.1\aapt2.exe"
Test-Path "$sdk\platforms\android-35\android.jar"

# Environment integrity
[Environment]::GetEnvironmentVariable('JAVA_HOME','User')
[Environment]::GetEnvironmentVariable('JAVA_HOME','Machine')
$env:ANDROID_HOME; $env:ANDROID_SDK_ROOT

# Godot's own Android paths
Select-String -Path "$env:APPDATA\Godot\editor_settings-4.7.tres" -Pattern 'export/android'

# Disk
[math]::Round((Get-PSDrive C).Free/1GB,2)
```

---

## 10. Discrepancies found while writing this record

| Item | Finding | Action |
|---|---|---|
| Blender version | The installer folder says `Blender-4.5.15`; `blender --version` reported `4.5.15 LTS` during M0. | Consistent. Blender is not launched by any current ticket. |
| Python | Default `python` is 3.15; the solver tooling targets 3.12. | Scripts must call `py -3.12` explicitly. Recorded, not changed. |
| G1 disk figures | Plan estimated ~2.4 GB installed; actual is ~2.87 GB (templates larger than estimated). | Within tolerance; no action. |
| `sdkmanager` version string | Reports `1.1.16717390 (Android CLI)` for `--version`, while the package is `23.0.0`. | Cosmetic; both are recorded above. |

---

## 11. What this record does not authorise

No installation, update, removal, PATH change, `JAVA_HOME` change, registry edit or SDK reconfiguration. Any change to this toolchain requires a ticket and, where the G1 plan is affected, owner approval.

---

## 12. Pinned identifiers and digests (QA cycle 2)

Build identifiers are enough where the tool publishes one; the engine and
templates also have SHA-256 digests so a rebuild can be checked on another
machine.

| Component | Version | Identifier / digest |
|---|---|---|
| Godot console binary | 4.7.2.stable | build `ed1daf0bf`; SHA-256 `C8F0A6BC45A19B33541501E57F6F7CD972AB18453743266339D495CBBE846643` |
| Godot editor binary | 4.7.2.stable | SHA-256 `AB1824F85BFD8E0E4128182C000C4003A3E042245B2967848D089B2A04B22424` |
| Android debug template | 4.7.2.stable | SHA-256 `59E0073F0FA59F552684A861D8F4266B0B34B488A140D6657EAC7DD70D1A0A0D` |
| Temurin JDK | 17.0.21+9 | build string `17.0.21+9` |
| Android build-tools | 35.0.1 | package id `build-tools;35.0.1` |
| Git | 2.55.0.windows.3 | version string |
| Python (solver) | 3.12.10 | `py -3.12 --version` |
| Blender | 4.5.15 LTS | folder + `blender --version` |

### Blender drift check

Before any Blender-based asset export:

1. run `blender --version` and compare to `4.5.15 LTS`;
2. record the output and date in this file;
3. if it differs, stop and open a decision ticket — do not re-export silently.

### Upgrade policy

Godot **4.8** and Blender **5.3** must not be adopted mid-project without a
decision record and a full regression run (rules, parity, flow, APK
verification). Patch-level Godot updates require the same test gate.

## 13. Build and test commands

```powershell
$env:GODOT = 'C:\Tools\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe'  # optional
powershell -ExecutionPolicy Bypass -File tools\test.ps1
powershell -ExecutionPolicy Bypass -File tools\build_debug.ps1
powershell -ExecutionPolicy Bypass -File tools\build_rc.ps1
```

The scripts do not contain credentials or personal paths. The editor settings
paths above are machine-local and must be recreated on another machine.


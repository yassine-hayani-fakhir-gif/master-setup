![Master Setup](docs/banner.svg)

# Master Setup

**Choose once. Deploy with visibility.**

Master Setup prepares a Windows installation from USB media, then runs Office
and a selected application queue. It is a Windows PowerShell 5.1 desktop project
with a native launcher, progress reporting and per-step logs.

**0.18.1 Preview · Multilingual core interface · Developed by Yassine**

> Preview software, not production-certified. Windows deployment erases the
> selected internal disk after confirmation. Start with a disposable VM and a
> snapshot. The app-only workflow does not reinstall Windows or partition disks.

## Source checkout versus release package

This repository contains source code. Native executables are built using
`scripts/Build-Windows.ps1` and are not committed. Until a release ZIP is published,
use `Start-MasterSetup.cmd` to test the interface from a trusted source checkout;
Windows deployment additionally requires a built `Kit/DiskGuard.exe`.

## Try the apps first

1. For a trusted unsigned download, right-click the ZIP, open Properties, and use Unblock if offered. Extract the entire release ZIP; keep `App.ps1`, `Kit` and the launcher together.
2. Double-click `MasterSetup.exe` on Windows x64. It opens the desktop UI without a command window; keep it beside `App.ps1` and `Kit`.
3. Choose **Install apps on this PC**.
4. Add your full installers, review the detected modes and choose **Install selected apps on this PC**.

Third-party installers are not included. An `.exe` or `.msi` extension alone does
not prove that a package can install offline. Close running applications before
updating them; the vendor installer may close an existing instance.

## Automatic app profiles

| Package | Default operation | Internet |
| --- | --- | --- |
| VLC official `vlc-<version>-win64.exe` | `/S /L=1033`, English silent setup | Full package works offline |
| WinRAR official `winrar-x64-<version><language>.exe` | `-s1`, silent defaults | Full package works offline |
| Brave `BraveBrowserStandaloneSetup.exe` | `/silent /install`, machine installation | Full package works offline |
| Brave `BraveBrowserStandaloneSilentSetup.exe` | No extra flags, user installation | Full package works offline |
| Chrome Enterprise standalone MSI | Standard quiet MSI installation | Full package works offline |
| Other MSI | `/qn /norestart REBOOT=ReallySuppress` | Depends on package dependencies |
| Other EXE | Configure documented silent arguments, or explicitly choose manual | Depends on package |

Known EXE profiles require both a recognized filename and the expected signed
publisher, and are rechecked before execution. Do not rename a download launcher
to a standalone filename. The picker rejects common Chrome/Brave web-launcher names
and explains which package to obtain. This is a useful heuristic, not universal
proof that an installer is offline.

An unknown EXE does **not** quietly fall back to a manual wizard. Configure it
before starting the queue. Advanced custom arguments are passed directly to the
selected executable, not evaluated as PowerShell or a shell command. Custom mode
cannot guarantee silent behavior or prevent a vendor-initiated reboot.

For online setup, the preparation page also offers **WinGet** (Brave, Chrome,
WinRAR, VLC) and **Ninite**. WinGet requires App Installer; neither option promises
offline installation. Check each vendor license before redistributing packages.

## Windows and Office workflow

1. Start from an existing working Windows x64 system as administrator.
2. Select apps and optional Office, then the internal target disk and Windows ISO.
3. Choose Windows edition, keyboard and one administrator account.
4. Review the disk identity and explicitly confirm erasure.
5. Master Setup stages files, creates a one-time boot entry and restarts into the
   installation environment. A separate native disk guard checks the target again.
6. After Windows, Office and the application queue run with visible progress.

Keep the source USB connected until this workflow finishes. NTFS or exFAT source
USBs are supported; Ventoy is optional when starting from working Windows.
UEFI targets must already be GPT; BIOS targets must already be MBR. This workflow
does not initialize RAW disks and refuses encrypted target volumes. Windows 11
checks here are preliminary, not a complete hardware compatibility certification.

Office uses the supplied ISO/IMG and the Microsoft installer; its own UI may
require attention. **No Windows or Office activation commands are executed.**
Broken-system / standalone bootable WinPE work is deferred. Experimental source
remains under `PE` and `Kit/DeployPE.ps1`, outside the main 0.17 workflow.

## Progress and recovery

- A sequential queue avoids concurrent MSI installation conflicts.
- Elapsed time and app position are visible; copy operations show bytes, speed
  and percentage. Installer percentages are never invented.
- Results distinguish an installer exit, a detected installed executable,
  a skipped package and an error. Executable presence does not prove the exact
  newly installed version when an older version was already present.
- Successful exit markers include package hash, mode and custom arguments.
  Rerunning an unchanged queue skips previously successful packages, not failures.
  Markers are a history of execution, not a full software inventory.
- After 15 minutes, the queue stops without killing the installer. Inspect and
  finish/close it before retrying. Reboot-required codes also stop the queue.
- **Skip this app** requires explicit confirmation that the installer is no longer
  working; it leaves the process open and records the app as unverified.
- Use **Open detailed log** to inspect errors. Do not publish logs containing
  serial numbers, account information or unattended answer files.

Full local packages avoid repeated downloads. Verified NTFS media reuse is
retained from earlier releases. Actual speed depends on media, disk and installer;
no installation-time benchmark is claimed.

## Development and validation

```powershell
powershell.exe -NoProfile -File scripts\Test-Project.ps1
```

This runs parser checks and non-destructive mocks. GitHub Actions includes Windows
PowerShell 5.1 tests plus native disk-guard and launcher regression tests. Extract
the contents of the `MasterSetup` folder as your repository root so `.github` is
at the repository root. Executable builds are described in `scripts/Build-Windows.ps1`.

**Validation for this delivery:** native mock tests passed (13 disk-guard scenarios
and launcher failure/success scenarios); archive checksums and source wiring were
checked. Windows PowerShell, WinForms and real application installations could not
be executed in the Linux build environment. Use [the test checklist](docs/TESTING.md)
before announcing a stable release. A CI configuration is not evidence of a passed CI run.

The launcher/scripts are unsigned. Do not disable Defender or machine security
policy. Follow your environment code-signing requirements. See [SECURITY.md](SECURITY.md).

## Project layout

- `App.ps1` — device overview and workflow selection
- `Kit/LocalApps.ps1` — profiles, package validation, queue and results
- `Kit/LocalAppsUI.ps1` — application selection and custom profile editor
- `Kit/Suivi.ps1` — responsive progress window and detailed journal
- `Kit/Auto.ps1` / `Finish.ps1` — Windows preparation and post-installation
- `Tests` — non-destructive regression checks
- `docs` — test matrix and release preparation

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). New automatic profiles need an official
installer reference, publisher validation, documented flags, and an offline/online
VM test. Do not assume `/S` works for every EXE.

MIT-licensed project code. Windows, Office and bundled-by-user applications retain
their own licenses. See [LICENSE](LICENSE).

## 0.17.1 startup hotfix

Fixed an invalid variable interpolation in Auto.ps1 that blocked source validation.
MasterSetup.exe is the primary entry point; Start-MasterSetup.cmd is a diagnostic fallback.
The native launcher is unchanged and still uses Windows PowerShell internally.
This is a folder-based portable application, not a single standalone executable.
No execution policy or antivirus settings are disabled. Organization signing policies still apply.

Validation: native launcher mock tests and a variable-colon regression scan pass on Linux.
Windows PowerShell parser, WinForms and installer execution must still be tested on Windows.

## 0.17.2 review and account fix

A scrollable review dialog lists the chosen Windows ISO/edition, disk and serial,
Office, app queue, keyboard and account before erasure approval. No/cancel is the
default. The password itself is never displayed.

Empty passwords now produce an explicit encoded empty value in both LocalAccount
and AutoLogon, instead of omitting LocalAccount/Password. This affects new profiles
only. Existing accounts are not modified. Static wiring checks pass; PowerShell
regression tests are included but have not run here. Test first logon with empty
and nonempty passwords in a disposable Windows VM before real deployment.

## 0.18 language and completion behavior

Choose English, Français, العربية or Español in the home-page selector. Core
controls, common prompts and the final review are translated; technical logs,
vendor installer windows and some explanatory text are not yet localized. Arabic
labels use right-to-left direction. This setting does not change Windows keyboard
or Office language. The prepared post-installation payload remembers the choice.

Office success-page closure recognizes explicit completion text and a Close
button in a recent, Microsoft-signed Office/setup process. Unknown or error pages
are left visible. This does not convert retail setup into an ODT silent installer.

The executable has been rebuilt with a hidden console compatibility launch. If it
still fails, retain `%TEMP%\MasterSetup-startup-*.log` and any error dialog; CMD
remains available for diagnosis. On the reported PC, the startup log identified an unsigned downloaded script blocked
by PowerShell. For a trusted download, unblock the ZIP in Properties before extracting;
do not disable Defender or change organization policy.

## Publication

See [the publishing checklist](docs/PUBLISH.md) and [LinkedIn draft](docs/LINKEDIN_POST.md).
0.18.1 separates the language selector from the version badge, revises Arabic
control updates and restyles the review. These are preview changes awaiting
Windows UI validation. See CHANGELOG.md and docs/TESTING.md for limitations.

## Signing preparation

This archive remains **unsigned**. See [SIGNING.md](docs/SIGNING.md) for the
certificate-store signing workflow. A trusted publisher certificate is required;
none is included or provisioned. The script has not been executed with a certificate.

## Code signing policy

This preview is unsigned. See [Code signing policy](docs/CODE_SIGNING_POLICY.md),
[privacy](docs/PRIVACY.md), [removal instructions](docs/UNINSTALL.md), and
[SignPath application preparation](docs/SIGNPATH_APPLICATION.md). No application
has been submitted and eligibility is not yet confirmed.

## Experimental boot mode

For a blank disk or Windows that cannot start, see [Boot Preview](docs/BOOT_MODE.md).
This separate UEFI WinPE path stages local packages and releases USB only after
Windows image application and internal boot preparation. It requires building a
WinPE ISO with Microsoft ADK on Windows and disposable-machine validation.
The working-Windows installation route is unchanged.

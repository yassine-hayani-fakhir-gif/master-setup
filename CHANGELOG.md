# 0.18.1 — UI polish preview

- Separate the language selector and version badge in the header.
- Snapshot child controls before translating. Avoid changing whole-form RTL and
  skip redundant text/RTL assignments to reduce handle recreation during Arabic
  switching. Guard language refresh callbacks and surface errors instead of exiting.
- Restyle installation review with navy/teal controls and comfortable padding.
  The target-disk erase warning and default Cancel action remain explicit.
- Add Windows-only regression tests for repeated language switches and input safety.
- Add publication notes and an English LinkedIn draft. No publication performed.

Arabic switching and visual layout still require Windows VM confirmation.

# 0.18 — Launcher, Office completion and language selector

- Rebuild the native GUI executable using a hidden new console for PowerShell
  compatibility, instead of CREATE_NO_WINDOW. Preserve startup logs and policies.
- Close recognized Office success pages through UI Automation. Require a recent
  Microsoft-signed Office/setup process, success heading, installation message and
  a Close button. Never kill Office or click through an error. Unknown pages remain open.
- Add English, French, Arabic and Spanish for core controls, common prompts and
  the installation review. Arabic text uses right-to-left direction. Technical
  logs, vendor UI and some explanatory text remain English/vendor language.
- Preserve selected language in the prepared post-installation payload.
- Remove a duplicated VLC entry in the WinGet selection list.
- Keep the 0.17.2 blank-password and review changes.

Validation: rebuilt native launcher passes mocked API tests. Static wiring and
archive integrity pass. PowerShell and UI Automation tests are supplied for Windows;
not executed here. Real Windows EXE startup and Office pages still need VM testing.

# 0.17.2 — Review and blank-password fix

- Add a scrollable confirmation window with ISO, edition, disk identity, Office,
  apps, keyboard, firmware and account settings. Cancel is the default button.
- Always emit an explicit encoded password, including the empty string, for both
  LocalAccount and AutoLogon. Previously LocalAccount omitted it when blank.
- Never include the actual password in the review or log.
- This changes newly generated profiles, not already installed accounts.
- Windows first-logon behavior still requires VM validation.

# 0.17.1 — Startup hotfix

- Fix `${firmware}:` interpolation in Auto.ps1.
- Make MasterSetup.exe the documented primary entry point.
- Add a static regression check for unbraced variable-colon references.
- Retain existing native launcher and deployment behavior.

# Changelog

## 0.17 Preview

- Add signed VLC EXE profile with silent English installation.
- Make unsupported EXEs require a profile before starting; manual mode is opt-in.
- Add an advanced custom-argument editor; preserve arguments in staged profiles.
- Reject common Chrome/Brave download launchers in the local installer picker.
- Add VLC to the online WinGet selection.
- Translate the main application, preparation and post-installation workflow to English.
- Replace the app list with columns for name, mode and package requirements.
- Fit the progress window to the working area and hide unused input fields.
- Add GitHub documentation, banner, contribution rules and an explicit test matrix.
- Keep Windows/Office activation absent and WinPE expansion deferred.

This preview is not a claim of tested universal EXE automation. The documented
profiles and advanced custom arguments still require VM validation.

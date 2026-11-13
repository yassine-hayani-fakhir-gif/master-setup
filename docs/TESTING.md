# Release test checklist — 0.17

Record Windows build, app version, filename, signature, mode, elapsed time and
result. Do not include personal serials or passwords in public test reports.

## Apps only, disposable VM

- [ ] Run `scripts/Test-Project.ps1` in Windows PowerShell 5.1.
- [ ] Disconnect VM networking. Install full VLC, WinRAR, Brave and Chrome MSI.
- [ ] No installer language/Next/Finish prompts for these supported packages.
- [ ] Open each app and verify its version and basic operation.
- [ ] Retry the same queue: previously successful packages are not rerun.
- [ ] Unknown EXE is blocked until configured; explicit manual mode works.
- [ ] Custom EXE arguments survive preparation and are passed unchanged.
- [ ] Changed file/signature is rejected before execution.
- [ ] ChromeSetup / BraveBrowserSetup download launchers are rejected in picker.
- [ ] WinGet online route installs the four selected apps on a connected VM.
- [ ] Missing WinGet produces a pending result, not a false success.
- [ ] Skip records an unverified result, not Installed.
- [ ] Timeout stops the queue and does not kill a running installer.
- [ ] Reboot-required exit stops remaining apps; resume after reboot.
- [ ] 1024x768 and 150% scaling: dialogs scroll, action buttons remain reachable.

## Destructive workflow, disposable disks only

- [ ] Windows 10 and Windows 11 preparation and first logon.
- [ ] Selected disk matches displayed model/size/identity.
- [ ] USB is never offered as the erase target.
- [ ] Unrelated internal disks are restored only after unique identity matching.
- [ ] Supported apps retain their modes after reboot; no silent/manual surprises.
- [ ] Office is installed from local image; no activation commands run.
- [ ] Insufficient RAM, storage, missing files and encrypted volumes fail clearly.

Do not turn these unchecked items into a claimed passing test report. Keep the
release marked Preview until the actual deployment matrix is completed.

## 0.18.1 release gates (not yet executed on Windows)

- [ ] Launch the EXE on Windows 10 and Windows 11; retain startup logs on failure.
- [ ] Switch all four languages repeatedly, including Arabic, without exceptions.
- [ ] Verify selector/version spacing at 100%, 125% and 150% scaling.
- [ ] Verify inputs, app mode and queue do not change during language switching.
- [ ] Review dialog: target identification readable, Cancel is default, close cancels.
- [ ] Fresh install with empty password: first and second logon succeed.
- [ ] Office success page closes; error and active installation pages remain open.
- [ ] GitHub Actions Windows PowerShell parser and regression jobs pass.

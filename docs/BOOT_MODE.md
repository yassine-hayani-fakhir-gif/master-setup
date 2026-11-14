# Master Setup Boot Preview (0.19 experimental)

Clean installation for an authorized PC whose Windows does not start, whose disk
is blank, or whose account is inaccessible. This does not recover passwords,
unlock BitLocker, preserve existing accounts, or repair the previous installation.
Back up needed data first. The selected disk is erased after an explicit review.
No disk is erased merely by starting the boot environment.

## Prepare once on a working Windows PC

Install matching Microsoft Windows ADK Deployment Tools and WinPE add-on:
https://learn.microsoft.com/windows-hardware/get-started/adk-install

Use an administrator Windows PowerShell x64 console in the trusted project folder:

```powershell
.\PE\Build-MasterPE.ps1 -WindowsIso "D:\Windows.iso" -OfficeImage "D:\Office.img" -AppsFolder "D:\OfflineApps" -OutputFolder "C:\MasterBoot-output"
```

OfficeImage and AppsFolder are optional. OutputFolder must not already exist.
The builder extracts install.wim or install.esd from the Windows ISO. Split SWM
images are not supported. It creates a boot ISO and MasterSetupMedia folders;
it never formats your USB. Only top-level EXE/MSI files are copied from AppsFolder.
Installer dependencies stored beside an EXE are not supported as a package here.
Use complete standalone vendor installers; copying a downloader does not make
it offline. Office media must also contain the required installation payload.

Copy MasterSetup-WinPE-x64.iso and MasterSetupMedia onto the existing Ventoy data
partition (NTFS/exFAT). Do not copy WinPE-build. The boot ISO must be tested with
your Ventoy version, firmware and Secure Boot configuration before field use.
The Build Master Setup Boot ISO workflow can produce a boot-only ISO artifact.
It includes WinPE and Master Setup, but no Windows installation image, Office or apps.
Generating an ISO is not evidence of a successful boot or end-to-end deployment.

## Each computer

1. Start from USB in UEFI x64 mode and select the Master Setup boot ISO.
2. Select local apps or no apps, Office if wanted, then the extracted Windows image.
3. Select Windows edition, keyboard, internal disk, account and computer name.
4. Review the computer identity and every choice. Cancel leaves the disks unchanged.
5. After confirmation the target is erased, files are copied and SHA-256 checked,
   Windows is applied locally, and the finalization payload and UEFI boot are prepared.
6. Wait for the green **USB CAN BE REMOVED** notice. Remove USB and enter Y to reboot.
7. Move USB to the next PC. The first PC continues Windows setup and local
   Office/application installation after first logon without requiring USB.

**Timing:** copying alone does not release USB in this preview. Applying Windows
and verifying the boot files must finish first. This avoids an early green notice
on a disk that cannot yet boot. Operator confirmation is still required to reboot.
The initial USB boot remains necessary; no working local OS is required.

BCDBoot explicitly targets this disk's EFI partition. With /s it does not create a
new firmware NVRAM entry. The fallback EFI loader is checked, but some firmware
requires manually selecting the prepared internal disk from Boot Menu.
https://learn.microsoft.com/windows-hardware/manufacture/desktop/bcdboot-command-line-options-techref-di

## Failure and limitations

- UEFI x64 only; use a Windows image licensed and compatible with the target CPU,
  TPM, RAM and firmware. This mode is not a Windows 11 eligibility bypass.
- Keep USB connected if copying, DISM or boot preparation fails. Old data is not
  restored after erasure. There is no automatic rollback or interrupted-apply resume.
- Runtime lives on X: RAM. Stage logs are on the internal MasterStage folder once
  that folder exists. A power loss before preparation finishes requires boot USB again.
- Keep C:\MasterStage-<id> and C:\SetupKit until Windows, Office and apps are verified.
  Answer files contain recoverable account credentials; protect access to the disk.
- Optional storage drivers can be added under Kit/Drivers/WinPE before building.
  This preview does not inject them into installed Windows: target-OS storage driver
  support must also exist, or Windows may fail to boot.
- Hardware failure, firmware passwords and inaccessible encrypted data need separate
  authorized support. The application does not remove these protections.
- No dedicated Windows Recovery partition is provisioned by this initial boot mode.
- Offline installation depends on the selected installers. Unknown/manual installers,
  vendor prompts, OOBE or firmware may still require operator interaction.

## Required disposable-VM validation

Automated tests cover source/target identity and USB release prerequisites only.
A real ADK build and boot/deployment are **not yet validated** by CI.

- Blank UEFI disk, then a broken Windows installation; Windows 10 and 11 separately.
- Cancel review: no disk changes. Source USB and unrelated internal disk unchanged.
- Disconnect source before green: failure, no USB-ready message, no automatic reboot.
- Remove source after green: internal boot and first logon succeed.
- Full Office and supported standalone apps install with USB removed and network off.
- Empty and nonempty account password, repeated reboot, correct computer identity.
- Copy corruption, missing payload, DISM failure and BCD failure never release USB.
- Multiple internal disks, storage-driver requirements and actual target firmware.

Do not deploy across a customer fleet until these cases pass on disposable systems.

## Boot-only ISO

Run `PE/Build-MasterPE.ps1 -OutputFolder "C:\MasterBoot-output"` without WindowsIso
to build just the boot environment. The GitHub workflow does this automatically.
Download the successful run's MasterSetup-Boot-0.19-experimental-x64 artifact,
extract it, and copy MasterSetup-WinPE-x64.iso onto Ventoy.
Mount your own Windows ISO on a working PC and copy sources/install.wim or
sources/install.esd to USB under MasterSetupMedia/Windows. Create Office and Apps
folders alongside it for your own full installers. Split install.swm is unsupported.
Compare the ISO SHA-256 with SHA256SUMS.txt before testing.

First boot test: disposable UEFI VMware VM, 4 GiB RAM minimum, blank virtual disk
of at least 64 GiB plus enough room for all packages. Attach the ISO as CD/DVD.
For deployment, also pass through a separate NTFS/exFAT USB containing the media;
this preview deliberately refuses a virtual SATA disk as the installer source.
Do not attach a host physical disk as the target. Seeing the interface is only
the first test; follow the full validation matrix above before customer use.

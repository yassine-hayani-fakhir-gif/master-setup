# Publish Master Setup 0.18.1 Preview

Author: Yassine Hayani Fakhir

## Before uploading

1. Extract the release archive into a fresh directory.
2. Use the contents of the MasterSetup folder as the repository root so that
   .github/workflows/validate.yml is at the correct level.
3. Keep USB deployment profiles, installer media, personal logs, account answer
   files and third-party installers out of the repository. The supplied .gitignore
   covers the known paths; inspect the staged file list before committing.
4. Run scripts/Test-Project.ps1 using Windows PowerShell 5.1, then inspect the
   GitHub Actions result. The Windows checks have not been run in the build environment.
5. In a disposable VM, switch English -> Arabic -> French -> Spanish -> English;
   check that the window stays open and app selections/passwords do not change.
6. Check the installation review at the intended screen resolution. Cancel and
   window-close must stop deployment. Verify the selected disk and its serial.
7. Test an empty password on a fresh installation; test EXE launch and Office
   completion closure. Record failures as issues rather than claiming full support.

## Repository metadata

Name: master-setup
Description: Windows deployment assistant with USB media, a local installer queue,
visible progress, disk review and a multilingual desktop interface.
Topics: windows, powershell, deployment, automation, offline-installation, sysadmin
License: MIT (project code only; vendor installers are not redistributed).

Upload source under the repository root. The executable and DiskGuard binary are
ignored by git and should be attached in the ZIP release, not forced into source.
Create the first release as a prerelease tagged v0.18.1-preview. Attach the original
ZIP and its SHA-256 hash. Do not edit the ZIP after publishing its hash.

## Release notes

- Separate language selector and version badge.
- Arabic UI handling revised; Windows validation required.
- Consistent navy/teal installation review with explicit disk-erasure warning.
- Four-language core interface; technical logs and some help remain English.
- Native EXE launcher, Office success-page monitor and silent app profiles retained.
- No activation commands or antivirus exclusions.

## Demo and privacy

Show: start EXE -> choose language -> choose apps -> review -> app-only installation
-> results. Blur serial numbers, account names, UUIDs and local paths. Do not show
passwords or generated answer files. Link the repository in the LinkedIn draft only
after it exists. No GitHub or LinkedIn publishing has been performed by this package.

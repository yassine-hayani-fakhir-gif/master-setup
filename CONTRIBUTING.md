# Contributing

Target Windows PowerShell 5.1 x64. Keep the working-Windows deployment path and
app-only workflow separate. Do not add activation scripts or disable security tools.

For an installer profile, include:

1. Official download and documented silent flags, with exact casing.
2. Filename and signed publisher checks; unsigned support must stay explicit.
3. Exit-code handling, reboot behavior and a detection method with known limits.
4. Regression mocks and a real disposable-VM test, offline when claimed.
5. An English UI label and actionable error message.

Run `scripts/Test-Project.ps1`; test disk-related changes only on disposable VMs.
Never commit ISO images, third-party installer binaries, profiles, credentials,
signing keys, device identifiers or user logs. Screenshots must be redacted.

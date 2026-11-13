# Security and release trust

Master Setup is an experimental disk deployment tool. Disk erasure requires an
explicit target choice and final confirmation. Please report security findings
privately to the repository maintainer once the project has a public contact;
no contact address or GitHub repository is published by this package.

Do not attach passwords, licence keys, personal serial numbers, unattended files
or complete diagnostic logs to a public issue without reviewing/redacting them.

Release checklist:
- Review all code changes and run non-destructive and disposable-machine tests.
- Build on a controlled Windows environment. Authenticode-sign EXE/PS1 files
  using a trusted, consistent publisher identity; never store signing secrets in Git.
- Scan the exact signed artifact. Generate checksums after signing.
- A valid signature does not guarantee immediate SmartScreen reputation.
- For an actual false-positive detection, submit the exact file to Microsoft:
  https://www.microsoft.com/en-us/wdsi/filesubmission
- Do not disable protection or add exclusions to make a release run.

References:
https://learn.microsoft.com/windows/apps/package-and-deploy/code-signing-options
https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation

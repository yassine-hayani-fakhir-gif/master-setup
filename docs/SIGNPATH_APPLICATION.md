# SignPath application preparation — NOT SUBMITTED

Project: Master Setup
Maintainer: Yassine Hayani Fakhir
License: MIT
Repository: https://github.com/yassine-hayani-fakhir-gif/master-setup
Public binary release: not yet published.

Description for the application:
Master Setup is a Windows deployment assistant with a PowerShell desktop interface
and native C launcher/disk guard. It prepares user-selected Windows media, requires
explicit target-disk review and confirmation, and runs user-selected Office and
application installers. Vendor installers and operating-system media are not
included in our release. Our project contains no activation bypass or antivirus
exclusion functions. The project is an unsigned preview and still undergoing
Windows validation.

Proposed artifacts: the Master Setup launcher, DiskGuard and maintained PowerShell
scripts, packaged without third-party installers or personal deployment profiles.
Signing eligibility and PowerShell artifact handling must be confirmed by SignPath.

Remaining prerequisites:
- Publish the source repository and a documented unsigned preview release.
- Confirm the maintainer's GitHub identity and enable MFA.
- Run Windows tests and publish honest results, including known limitations.
- Add consistent product/version resources to both native executable builds.
- Build release artifacts from source using a verifiable CI workflow.
- Confirm signing roles and review responsibilities.
- Ask SignPath whether the project has sufficient verifiable reputation; a newly
  published repository is not automatically eligible.
- Apply only with real repository/release links. Do not claim prior approval.

Application: https://signpath.org/apply
Requirements: https://signpath.org/terms.html

No credentials, API keys or certificates belong in this file or repository.

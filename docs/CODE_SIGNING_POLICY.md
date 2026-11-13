# Code signing policy

Status: unsigned preview. No SignPath application has been submitted or approved.
This page describes the proposed signing policy, not an existing partnership.

Project: Master Setup
Maintainer and proposed author/reviewer/approver: Yassine Hayani Fakhir.
GitHub: https://github.com/yassine-hayani-fakhir-gif
Repository: https://github.com/yassine-hayani-fakhir-gif/master-setup

Only Master Setup artifacts built from this repository may be submitted for
signing. Windows media, Office media and third-party app installers are supplied
separately by users and must never be signed under this project's identity.
Each signing request must be manually approved by the responsible maintainer.
Multi-factor authentication must be enabled for GitHub and SignPath access.
Changes from outside contributors require review before merging or releasing.

The executable launcher and DiskGuard must be built in a verifiable Windows CI
workflow. Product name and version metadata must be added to both native binaries
and enforced in the signing configuration before applying. Existing local binary
builds are not represented as SignPath-verified builds.

See PRIVACY.md for local data, network operations and third-party behavior.
See UNINSTALL.md for removal and deployment limitations.

If SignPath approves the project, update this page and release pages to include
its required service attribution. Do not advertise signed releases before approval.

Official requirements: https://signpath.org/terms.html

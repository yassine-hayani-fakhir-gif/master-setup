# Privacy

Master Setup's own scripts do not implement analytics or upload logs to a project
server. Hardware identifiers, computer names, file paths, installer hashes and
results are read locally and may appear in local logs or staged profiles.
Generated Windows answer files contain recoverable account credentials. Encoding
is not encryption. Protect the USB and remove unneeded profiles after deployment.
Never publish profiles or unredacted logs in GitHub issues or demo screenshots.

User-selected online actions can open Microsoft download pages or run WinGet,
Ninite, Office and other vendor installers. These programs and Windows services
may contact their vendors, including for downloads, updates, certificate checks
and licensing. Their privacy policies apply. Local full installers reduce download
needs but do not guarantee zero network traffic from Windows or vendor software.

The signing workflow, when explicitly run, contacts the configured timestamp
service and certificate-validation services. It does not export the private key.

No project telemetry endpoint or remote management service is included. The
maintainer receives only information the user explicitly shares.

# Trusted signing — prerequisites and workflow

This package is UNSIGNED. Adding this workflow does not remove SmartScreen warnings.
No certificate has been purchased or applied, and nothing has been published.

## What you need

- A trusted code-signing certificate issued to you or your organization, with its
  private key accessible through the Windows certificate store and provider/token.
- A Windows PC with Windows PowerShell 5.1 and SignTool from the Windows SDK.
- Your certificate provider's RFC 3161 timestamp URL and an Internet connection
  for certificate-chain/revocation checking and timestamping.
- Completed project tests and a review of the exact files being signed.

Do not send anyone your private key, PFX, PIN, password or service credentials.
A certificate thumbprint is a public identifier, not a private key.
The script supports certificate-store signing. Cloud services requiring a separate
SignTool plugin/authentication flow need their provider-specific integration.
It does not register a cloud account or buy a certificate.

## Find available certificates (read-only)

```powershell
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert |
    Select-Object Subject, Thumbprint, NotAfter, HasPrivateKey
```

If none are listed, stop here: the signing identity is not configured.
Do not generate a self-signed certificate as a substitute for a publicly trusted one.

## Sign an isolated release copy

Build the native binaries with scripts/Build-Windows.ps1 on your trusted Windows
build machine. Run from a Developer PowerShell where signtool.exe is on PATH.
Replace the placeholders with the certificate thumbprint and provider timestamp URL:

```powershell
.\scripts\Sign-Release.ps1 `
  -Thumbprint 'YOUR_40_CHARACTER_CERTIFICATE_THUMBPRINT' `
  -TimestampServer 'https://YOUR_PROVIDER_RFC3161_TIMESTAMP_URL' `
  -OutputDirectory 'C:\MasterSetup-Releases\0.18.1-signed'
```

The output directory must not exist and must be outside the source tree. The
workflow validates the certificate, runs tests, copies files, signs EXE and
PowerShell files with SHA-256, timestamps, verifies every signature, reruns tests,
and generates hashes and the ZIP after signing. It never exports the private key.
A partial failure leaves SIGNING-FAILED.txt; do not distribute that directory.

Keep signed files unchanged. Publish the final ZIP and its .sha256 file together.
A valid certificate establishes publisher identity; it is not proof of application
safety and does not guarantee immediate SmartScreen reputation.

## Status of this delivery

The signing workflow was statically reviewed on Linux. It has NOT been executed
with a real certificate or Windows SignTool. The application remains a preview.

References:
- https://learn.microsoft.com/windows/win32/seccrypto/signtool
- https://learn.microsoft.com/windows/apps/package-and-deploy/smartscreen-reputation

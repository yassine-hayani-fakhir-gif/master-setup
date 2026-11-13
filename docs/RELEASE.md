# Preparing a public release

- Complete TESTING.md and attach a redacted result table.
- Run the Windows GitHub Actions job; fix failures before tagging.
- Keep the version labelled Preview if the Windows deployment matrix is incomplete.
- Review .gitignore before the first commit. Commit project source, not USB contents.
- Build/sign in a trusted Windows environment if signing is available; do not
  suppress antivirus or execution-policy checks to make a release work.
- Regenerate SHA256SUMS.txt after the final build/signing step.
- Capture the real UI at a readable resolution with serials, usernames and passwords hidden.
- For a LinkedIn demonstration, show app selection, a silent VLC installation,
  progress/results and the installed app. State which scenarios were actually tested.
- Publishing to GitHub or LinkedIn is not performed by this release archive.

## Windows CI preview package

The `Validate source` workflow builds both x64 executables on Windows using
clang-cl and the Windows SDK. It verifies ProductName/ProductVersion and uploads
`MasterSetup-0.18.1-UNSIGNED-x64` containing the ZIP and its SHA-256 checksum.
The ZIP contains BUILD.json with the source commit and workflow run, and an
internal file checksum manifest. Download from a successful Actions run.
These are unsigned preview artifacts, not SignPath-approved releases.

For a local build, open an x64 Visual Studio developer shell with LLVM installed,
run `scripts/Build-Windows.ps1`, then `scripts/Package-Preview.ps1` from a clean
Git checkout. Packaging rejects an existing dist directory.
End-to-end disk erasure/installation tests must use disposable test machines.

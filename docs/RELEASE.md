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

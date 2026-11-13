"""Narrow regression guard; not a replacement for the PowerShell parser."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
allowed = {"env", "script", "global", "local", "private", "using", "function", "variable"}
issues = []
for path in root.rglob("*.ps1"):
    for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        for match in re.finditer(r"\$([A-Za-z_][A-Za-z0-9_]*):", line):
            if match[1].lower() not in allowed:
                issues.append(f"{path.relative_to(root)}:{number}: {match[0]}")
if issues:
    raise SystemExit("Unexpected variable-colon references:\n" + "\n".join(issues))
print("PASS: variable-colon regression scan (not a full PowerShell syntax check).")

#!/usr/bin/env python3
"""Lines that would make the plugin marketplace's security baseline report
the "privilege" capability: a reference to sudo or pkexec that is not
explicitly negated ("No sudo or pkexec is required" is fine). A port of
invokesPrivilegeBoundary in omacom/omarchy-plugin-marketplace's
scripts/security-baseline-analysis.mjs. Usage: privilege.py FILE...
Prints path:line:text for each hit; exits 1 if any."""
import re
import sys

NAMES = r"(?:sudo|pkexec)"
LIST = rf"{NAMES}(?:\s*(?:,|/|\bor\b|\band\b)\s*{NAMES})*"
EXPLICIT_NEGATIVE_LIST = rf"{NAMES}(?:\s*(?:/|\bor\b|\band\b)\s*(?:no\s+)?{NAMES})*"
NEGATIVE = r"\s+(?:is|are)(?:\s+not)?\s+(?:required|needed)\b"
NOT_USED = r"\s+(?:is|are)\s+not\s+used\b"
NO_USE = r"\s+(?:is|are)(?:\s+not)?\s+used\b"
TERMINAL = r"(?=\s*(?:[.;!?]|,\s*(?:no|without)\b|$))"
STRIPS = [
    rf"\b(?:no|without)(?:\s+(?:use\s+of|using))?\s+{EXPLICIT_NEGATIVE_LIST}(?:{NEGATIVE}|{NO_USE})",
    rf"\b{LIST}(?:{NOT_USED}|\s+(?:is|are)\s+not\s+(?:required|needed)\b)",
    rf"\b(?:no|without)(?:\s+(?:use\s+of|using))?\s+{LIST}{TERMINAL}",
    rf"\b(?:does\s+not|doesn't|do\s+not|don't|never)\s+(?:use|run|invoke|require|need)\s+{LIST}{TERMINAL}",
]


def privileged(text):
    for pattern in STRIPS:
        text = re.sub(pattern, "", text, flags=re.IGNORECASE)
    return re.search(rf"\b{NAMES}\b", text, re.IGNORECASE) is not None


def main(paths):
    hits = 0
    for path in paths:
        with open(path, "rb") as f:
            data = f.read()
        if b"\0" in data:
            continue  # binary (fonts, sounds, images)
        lines = data.decode("utf-8", errors="replace").splitlines()
        for n, line in enumerate(lines, 1):
            if privileged(line):
                print(f"{path}:{n}:{line.strip()}")
                hits += 1
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

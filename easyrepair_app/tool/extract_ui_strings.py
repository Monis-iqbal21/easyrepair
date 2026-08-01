"""Finds visible, app-owned string literals still hard-coded in Dart UI code.

Used to drive the localization migration and, afterwards, as the hard-coded
string audit. It deliberately over-reports rather than under-reports: every hit
is classified by hand into one of

  1. dynamic / user / backend content that must NOT be translated
  2. protected bottom-navigation English
  3. internal technical value (route, enum, mime type, asset path, log)
  4. a missed translation

Run:  python tool/extract_ui_strings.py [path ...]
"""

import io
import os
import re
import sys

# String literals in these argument positions are shown to a user.
UI_CONTEXTS = [
    r"Text\(\s*",
    r"Text\(\s*\n\s*",
    r"SelectableText\(\s*",
    r"TextSpan\(\s*text:\s*",
    r"label(?:Text)?:\s*",
    r"hint(?:Text)?:\s*",
    r"helperText:\s*",
    r"errorText:\s*",
    r"title:\s*",
    r"displayTitle:\s*",
    r"heading:\s*",
    r"headline:\s*",
    r"caption:\s*",
    r"body:\s*",
    r"text:\s*",
    r"description:\s*",
    r"placeholder:\s*",
    r"emptyText:\s*",
    r"buttonText:\s*",
    r"actionLabel:\s*",
    r"subtitle:\s*",
    r"content:\s*",
    r"message:\s*",
    r"tooltip:\s*",
    r"semanticLabel:\s*",
    r"prefixText:\s*",
    r"suffixText:\s*",
    r"counterText:\s*",
    r"return\s+",
    # Switch-expression arms: `BookingStatus.arrived => 'text'`.
    r"=>\s*",
    # Ternary branches: `locked ? 'Coming Soon' : 'Book Now'` — both arms are
    # display text and were previously invisible to this scan.
    r"\?\s*",
    r":\s+(?=')",
]

# Values that are never user-visible copy.
TECHNICAL = re.compile(
    r"^("
    r"assets/|/|https?://|[a-z_]+\.dart$|package:|dart:"
    r"|[A-Z][A-Z0-9_]+$"                 # SCREAMING_CASE enum tokens
    r"|[a-z]+/[a-z0-9.+-]+$"             # mime types
    r"|#[0-9a-fA-F]{3,8}$"
    r"|[a-z][a-zA-Z0-9]*$"               # single lowerCamel word: keys, ids
    r"|[0-9\s.,:%+-]*$"                  # numeric / punctuation only
    r")"
)

LITERAL = r"'((?:[^'\\\n]|\\.){2,200})'"

# Named arguments whose value is never display copy. These are matched by the
# generic `: '...'` rule above, so they are subtracted again here rather than
# polluting the audit with API values and asset paths.
NON_UI_PARAM = re.compile(
    r"\b(backendName|imagePath|route|routeName|assetPath|asset|package|"
    r"fontFamily|id|key|tag|type|mimeType|source|event|channel|url|uri|"
    r"path|emoji|iconName|analyticsId|semanticsIdentifier)\s*:\s*$"
)


def is_visible(value: str) -> bool:
    if not value.strip():
        return False
    if TECHNICAL.match(value):
        return False
    # Needs at least one letter to be readable copy.
    return bool(re.search(r"[A-Za-z؀-ۿ]", value))


def scan(path: str):
    src = io.open(path, encoding="utf-8").read()
    hits = []
    for ctx in UI_CONTEXTS:
        for m in re.finditer(ctx + LITERAL, src):
            value = m.group(1)
            if not is_visible(value):
                continue
            # Drop matches whose named argument is a technical one.
            if NON_UI_PARAM.search(src[max(0, m.start() - 40):m.start() + 1]):
                continue
            line = src.count("\n", 0, m.start()) + 1
            hits.append((line, value))
    return sorted(set(hits))


def report(path, total):
    hits = scan(path)
    if not hits:
        return total
    print(f"\n## {path.replace(os.sep, '/')}  ({len(hits)})")
    for line, value in hits:
        print(f"{line}\t{value}")
    return total + len(hits)


def main(argv):
    roots = argv[1:] or ["lib"]
    total = 0
    for root in roots:
        # A single file is a valid target too — os.walk alone would silently
        # report nothing for one, which reads as "clean" when it is not.
        if os.path.isfile(root):
            total = report(root, total)
            continue
        for dirpath, _dirs, files in os.walk(root):
            # Generated localizations are not hand-edited.
            if os.path.normpath(dirpath).endswith(os.path.join("lib", "l10n")):
                continue
            for name in sorted(files):
                if not name.endswith(".dart"):
                    continue
                path = os.path.join(dirpath, name)
                hits = scan(path)
                if not hits:
                    continue
                rel = path.replace("\\", "/")
                print(f"\n## {rel}  ({len(hits)})")
                for line, value in hits:
                    print(f"{line}\t{value}")
                total += len(hits)
    print(f"\nTOTAL {total}")


if __name__ == "__main__":
    main(sys.argv)

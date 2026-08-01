"""Rewrites hard-coded Dart string literals into `context.l10n.<key>` lookups.

Takes a JSON batch of {file: {literal: key}} and applies it safely:

  * replaces the exact single-quoted literal, including adjacent-literal
    concatenations Dart joins at compile time
  * drops `const` from any widget expression that now contains a runtime
    lookup, which the analyzer would otherwise reject
  * adds the l10n import once per file
  * reports every literal it could not find instead of silently skipping

It never invents translations — the ARB files are edited separately and remain
the single source of truth.

Run:  python tool/apply_l10n.py batch.json
"""

import io
import json
import re
import sys

IMPORT_RE = re.compile(r"^import\s+.*;$", re.M)


def rel_import(path: str) -> str:
    """Import path from a lib/ file back to core/l10n/l10n_extensions.dart."""
    parts = path.replace("\\", "/").split("/")
    depth = len(parts) - 2  # minus 'lib' and the filename
    return "../" * depth + "core/l10n/l10n_extensions.dart"


def add_import(src: str, path: str) -> str:
    target = "import '%s';" % rel_import(path)
    if "core/l10n/l10n_extensions.dart" in src:
        return src
    imports = list(IMPORT_RE.finditer(src))
    if not imports:
        return target + "\n" + src
    last = imports[-1]
    return src[: last.end()] + "\n" + target + src[last.end():]


def strip_const(src: str) -> str:
    """Remove `const` from constructor calls whose body needs a runtime value."""
    while True:
        removed = False
        for m in re.finditer(r"\bconst\s+(?=[A-Z_])", src):
            open_paren = src.find("(", m.end())
            if open_paren == -1:
                continue
            depth, i = 0, open_paren
            while i < len(src):
                if src[i] == "(":
                    depth += 1
                elif src[i] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            if "context.l10n" in src[open_paren:i + 1]:
                src = src[: m.start()] + src[m.end():]
                removed = True
                break
        if not removed:
            return src


def apply(path: str, mapping: dict) -> list:
    src = io.open(path, encoding="utf-8").read()
    missed = []
    for literal, key in mapping.items():
        replacement = "context.l10n.%s" % key
        # Dart concatenates adjacent string literals; match that form first so
        # a wrapped sentence is replaced as one unit.
        parts = literal.split("\x00")
        if len(parts) > 1:
            pattern = r"\s*".join(
                "'" + re.escape(p) + "'" for p in parts
            )
            new_src, n = re.subn(pattern, replacement, src)
        else:
            quoted = "'" + literal + "'"
            n = src.count(quoted)
            new_src = src.replace(quoted, replacement)
        if n == 0:
            missed.append(literal)
        src = new_src
    if missed:
        return missed
    src = strip_const(src)
    src = add_import(src, path)
    io.open(path, "w", encoding="utf-8", newline="").write(src)
    return []


def main(argv):
    batch = json.load(io.open(argv[1], encoding="utf-8"))
    failures = {}
    for path, mapping in batch.items():
        missed = apply(path, mapping)
        if missed:
            failures[path] = missed
    if failures:
        print("MISSED (no file was written for these):")
        for path, items in failures.items():
            for item in items:
                print("  %s :: %s" % (path, item))
        sys.exit(1)
    print("applied %d files" % len(batch))


if __name__ == "__main__":
    main(sys.argv)

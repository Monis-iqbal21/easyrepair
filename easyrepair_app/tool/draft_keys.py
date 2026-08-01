"""Drafts localization keys for the hard-coded strings still left in a feature.

Emits, for the files given:

  * a Python dict skeleton  key -> English   (translations are filled in by hand)
  * a batch JSON for tool/apply_l10n.py      (literal -> key, per file)

Key names are derived from a feature prefix plus a camel-cased slug of the
English text, which keeps them readable and stable. Collisions get a numeric
suffix; identical English inside one feature deliberately collapses onto a
single key, since that is the reuse the ARB parity test wants.

Run:  python tool/draft_keys.py <prefix> <path ...>
"""

import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_ui_strings import scan  # noqa: E402

STOPWORDS = {
    "a", "an", "the", "to", "of", "in", "on", "for", "and", "or", "is", "are",
    "be", "you", "your", "we", "our", "it", "this", "that", "with", "at",
}


def slug(text: str, limit: int = 5) -> str:
    text = re.sub(r"\$\{[^}]*\}|\$\w+", " ", text)      # drop interpolations
    text = re.sub(r"\\n|\\'", " ", text)
    words = re.findall(r"[A-Za-z]+", text)
    kept = [w for w in words if w.lower() not in STOPWORDS] or words
    kept = kept[:limit]
    if not kept:
        return "text"
    head = kept[0].lower()
    return head + "".join(w.capitalize() for w in kept[1:])


def main(argv):
    prefix, paths = argv[1], argv[2:]
    by_key = {}
    by_file = {}
    used = {}

    for path in paths:
        hits = scan(path)
        if not hits:
            continue
        mapping = {}
        for _line, value in hits:
            key = prefix + slug(value)[:1].upper() + slug(value)[1:]
            if key in used and used[key] != value:
                n = 2
                while f"{key}{n}" in used and used[f"{key}{n}"] != value:
                    n += 1
                key = f"{key}{n}"
            used[key] = value
            by_key[key] = value
            mapping[value] = key
        by_file[path.replace("\\", "/")] = mapping

    out_dir = os.environ.get("DRAFT_OUT", ".")
    with io.open(os.path.join(out_dir, "draft_batch.json"), "w",
                 encoding="utf-8") as handle:
        json.dump(by_file, handle, ensure_ascii=False, indent=1)

    with io.open(os.path.join(out_dir, "draft_keys.py.txt"), "w",
                 encoding="utf-8") as handle:
        handle.write("EN = {\n")
        for key, value in by_key.items():
            handle.write("  %s: %s,\n" % (json.dumps(key),
                                          json.dumps(value, ensure_ascii=False)))
        handle.write("}\n")

    print("%d keys across %d files" % (len(by_key), len(by_file)))


if __name__ == "__main__":
    main(sys.argv)

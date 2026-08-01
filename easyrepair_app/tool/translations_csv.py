"""Round-trips HandyGo translations between the ARB files and a review CSV.

The ARB files under lib/l10n are always the source of truth for the app. This
script exists so a non-developer can review or edit every string in one
spreadsheet and have the result written back safely.

    python tool/translations_csv.py export      # ARB  -> docs/handygo_translations.csv
    python tool/translations_csv.py validate    # check the CSV, touch nothing
    python tool/translations_csv.py sync        # CSV  -> ARB (validates first)

`sync` refuses to write anything unless every check passes, so a bad edit can
never leave the three ARB files half-updated.
"""

import csv
import io
import json
import os
import re
import sys
from collections import OrderedDict

ARB_DIR = os.path.join("lib", "l10n")
CSV_PATH = os.path.join("..", "docs", "handygo_translations.csv")

LOCALES = OrderedDict(
    [("en", "app_en.arb"), ("ur", "app_ur.arb"), ("ur_Latn", "app_ur_Latn.arb")]
)
COLUMN_FOR = {"en": "English", "ur": "Urdu", "ur_Latn": "Roman Urdu"}

# Keys deliberately absent from the translated ARBs; see arb_parity_test.dart.
INTENTIONALLY_UNTRANSLATED = {"l10nFallbackProbe"}

# Only real ICU arguments: a name closed by `}` or followed by `,` (as in
# `{count, plural, ...}`). Without the terminator this also captured the first
# word inside a plural branch, e.g. `=1{Arriving in ...}`.
PLACEHOLDER = re.compile(r"\{(\w+)\s*[,}]")

# Screen/context is derived from the key prefix so the CSV stays useful as keys
# are added, instead of drifting out of date in a hand-maintained table.
CONTEXT_BY_PREFIX = [
    ("language", "Settings / Language selector"),
    ("auth", "Authentication"),
    ("error", "Core / Errors"),
    ("permissions", "Core / Permissions"),
    ("general", "Settings / General info"),
    ("distance", "Core / Distance formatting"),
    ("notifications", "Notifications"),
    ("time", "Core / Relative time"),
    ("month", "Core / Date formatting"),
    ("date", "Core / Date formatting"),
    ("weekday", "Core / Date formatting"),
    ("chat", "Chat & Support"),
    ("bookingStatus", "Bookings / Status labels"),
    ("jobStatus", "Worker jobs / Status labels"),
    ("booking", "Bookings"),
    ("inspection", "Inspection flow"),
    ("worker", "Ustaad"),
    ("client", "Client"),
    ("bid", "Bidding"),
    ("review", "Reviews & ratings"),
    ("earning", "Earnings"),
    ("legal", "Legal"),
    ("common", "Shared"),
    ("l10n", "Localization self-test"),
]


def arb_path(name):
    return os.path.join(ARB_DIR, name)


def load_arb(name):
    with io.open(arb_path(name), encoding="utf-8") as handle:
        return json.load(handle, object_pairs_hook=OrderedDict)


def messages(arb):
    return OrderedDict(
        (k, v) for k, v in arb.items() if not k.startswith("@")
    )


def context_for(key):
    for prefix, label in CONTEXT_BY_PREFIX:
        if key.startswith(prefix):
            return label
    return "Uncategorised"


def notes_for(key, en_value, meta):
    notes = []
    placeholders = sorted(set(PLACEHOLDER.findall(en_value)))
    if placeholders:
        notes.append("Placeholders: " + ", ".join("{%s}" % p for p in placeholders))
    if "plural" in en_value:
        notes.append("ICU plural — keep the plural syntax intact")
    if key in INTENTIONALLY_UNTRANSLATED:
        notes.append("Intentionally untranslated: proves the English fallback")
    description = (meta or {}).get("description")
    if description:
        notes.append(description)
    return " | ".join(notes)


def export():
    arbs = {code: load_arb(name) for code, name in LOCALES.items()}
    en_arb = arbs["en"]
    en_messages = messages(en_arb)

    out_path = os.path.abspath(os.path.join(os.getcwd(), CSV_PATH))
    os.makedirs(os.path.dirname(out_path), exist_ok=True)

    with io.open(out_path, "w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            ["Key", "Screen/Context", "English", "Urdu", "Roman Urdu", "Notes"]
        )
        for key, en_value in en_messages.items():
            meta = en_arb.get("@" + key)
            writer.writerow(
                [
                    key,
                    context_for(key),
                    en_value,
                    messages(arbs["ur"]).get(key, ""),
                    messages(arbs["ur_Latn"]).get(key, ""),
                    notes_for(key, en_value, meta),
                ]
            )
    print("exported %d keys -> %s" % (len(en_messages), out_path))


def read_csv():
    path = os.path.abspath(os.path.join(os.getcwd(), CSV_PATH))
    if not os.path.exists(path):
        raise SystemExit("CSV not found: %s (run `export` first)" % path)
    with io.open(path, encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    required = {"Key", "English", "Urdu", "Roman Urdu"}
    if rows and not required.issubset(rows[0].keys()):
        raise SystemExit(
            "CSV is missing required columns: %s"
            % ", ".join(sorted(required - set(rows[0].keys())))
        )
    return rows


def icu_is_balanced(value):
    depth = 0
    for char in value:
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth < 0:
                return False
    return depth == 0


def validate(rows):
    """Returns a list of human-readable errors; empty means safe to sync."""
    errors = []
    en_arb = load_arb(LOCALES["en"])
    en_messages = messages(en_arb)

    seen = set()
    csv_keys = []
    for index, row in enumerate(rows, start=2):  # row 1 is the header
        key = (row.get("Key") or "").strip()
        if not key:
            errors.append("row %d: blank Key" % index)
            continue
        if key in seen:
            errors.append("row %d: duplicate key '%s'" % (index, key))
            continue
        seen.add(key)
        csv_keys.append(key)

        if key not in en_messages:
            errors.append(
                "row %d: unknown key '%s' — keys are defined in the ARB files, "
                "not in the CSV" % (index, key)
            )
            continue

        english = (row.get("English") or "").strip()
        if not english:
            errors.append("row %d (%s): English is blank" % (index, key))
            continue

        expected = sorted(set(PLACEHOLDER.findall(english)))
        for code in ("ur", "ur_Latn"):
            value = (row.get(COLUMN_FOR[code]) or "").strip()
            if not value:
                if key in INTENTIONALLY_UNTRANSLATED:
                    continue
                errors.append(
                    "row %d (%s): %s is blank" % (index, key, COLUMN_FOR[code])
                )
                continue
            actual = sorted(set(PLACEHOLDER.findall(value)))
            if actual != expected:
                errors.append(
                    "row %d (%s): %s placeholders %s do not match English %s"
                    % (index, key, COLUMN_FOR[code], actual, expected)
                )
            if not icu_is_balanced(value):
                errors.append(
                    "row %d (%s): %s has unbalanced { } — malformed ICU"
                    % (index, key, COLUMN_FOR[code])
                )
        if not icu_is_balanced(english):
            errors.append("row %d (%s): English has unbalanced { }" % (index, key))

    missing = [k for k in en_messages if k not in seen]
    if missing:
        errors.append(
            "CSV is missing %d key(s) present in app_en.arb: %s"
            % (len(missing), ", ".join(missing[:10]) + ("..." if len(missing) > 10 else ""))
        )
    return errors


def write_arb(name, existing, updates):
    """Rewrites one ARB, preserving key order, metadata and formatting."""
    out = OrderedDict()
    for key, value in existing.items():
        if key.startswith("@"):
            out[key] = value  # metadata and @@locale untouched
        elif key in updates:
            out[key] = updates[key]
        else:
            out[key] = value
    text = json.dumps(out, ensure_ascii=False, indent=2) + "\n"
    with io.open(arb_path(name), "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def sync():
    rows = read_csv()
    errors = validate(rows)
    if errors:
        print("VALIDATION FAILED — no ARB file was modified:\n")
        for error in errors:
            print("  - " + error)
        sys.exit(1)

    by_locale = {code: {} for code in LOCALES}
    for row in rows:
        key = row["Key"].strip()
        for code in LOCALES:
            value = (row.get(COLUMN_FOR[code]) or "").strip()
            if value:
                by_locale[code][key] = value

    for code, name in LOCALES.items():
        existing = load_arb(name)
        write_arb(name, existing, by_locale[code])
        print("updated %s (%d values)" % (name, len(by_locale[code])))
    print("\nNow run:  flutter gen-l10n")


def main(argv):
    command = argv[1] if len(argv) > 1 else "validate"
    if command == "export":
        export()
    elif command == "validate":
        errors = validate(read_csv())
        if errors:
            print("VALIDATION FAILED:\n")
            for error in errors:
                print("  - " + error)
            sys.exit(1)
        print("CSV is valid.")
    elif command == "sync":
        sync()
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main(sys.argv)

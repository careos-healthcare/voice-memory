#!/usr/bin/env python3
"""Fail on the `X! != null` / `X! == null` null-check-operator anti-pattern.

A postfix `!` is Dart's null-check operator: it throws
`_TypeError: Null check operator used on a null value` the instant its operand
is null. Writing it *inside* a null comparison — `if (ctx.field! != null)` — is
therefore self-defeating: when `field` is null (usually the common case) the `!`
throws before `!= null` can evaluate to false. The intent was always
`if (ctx.field != null)`; the `!` belongs in the block body, where the value has
been proven non-null, not in the guard.

This exact shape shipped ~80 times across the record-capture views and crashed
`RecordScreen` the moment it was allowed to build. The analyzer *does* catch it
(`unnecessary_null_comparison`: "the operand can't be 'null', so the condition
is always 'true'"), but `analysis_options.yaml` excludes the entire
`lib/features/*` symlink tree into `retired_sprawl/` — code the app still
compiles, ships, and (via ~1,000 test files) executes. So nothing analyzed it
and something still ran it: exactly how the crash survived.

Like `check_initstate_provider_writes.py`, this walks the source directly with
`followlinks=True`, so it covers the analyzer-excluded `retired_sprawl` symlinks
that a normal `flutter analyze` never sees. It is deliberately narrow — the one
textual anti-pattern that is *always* a bug — so it has no false positives and
runs in milliseconds, unlike a full `dart analyze` of the retired tree (minutes,
and swamped by isolation-resolution noise). It does not attempt the harder
"spurious `!` passed into a null-tolerant context" variant, which needs type
information; closing that fully is the retired_sprawl import burn-down's job.
"""

import os
import re
import sys

MOBILE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB_ROOT = os.path.join(MOBILE_ROOT, "lib")

# A postfix null-check operator (`!`) sitting immediately on the left of a
# `!= null` / `== null` comparison. The operand ends in a word char, `)` or `]`
# (`ctx.field!`, `foo()!`, `list[0]!`); `\s*` spans newlines, so the line-wrapped
# `field! !=\n    null` form is caught too. A prefix logical-not (`!flag == null`)
# never matches: an identifier sits between that `!` and the operator.
GUARD_ANTIPATTERN = re.compile(r"[\w\)\]]\s*!\s*[!=]=\s*null\b")


def blank_comments_and_strings(source):
    """Replace comment and string contents with spaces, preserving offsets.

    Keeps the anti-pattern from matching text that only appears inside a string
    literal or a comment (e.g. this docstring's examples in a ported file).
    """
    out = list(source)
    i = 0
    n = len(source)
    while i < n:
        ch = source[i]
        if ch == "/" and i + 1 < n and source[i + 1] == "/":
            while i < n and source[i] != "\n":
                out[i] = " "
                i += 1
            continue
        if ch == "/" and i + 1 < n and source[i + 1] == "*":
            depth = 1
            out[i] = out[i + 1] = " "
            i += 2
            while i < n and depth:
                if source.startswith("/*", i):
                    depth += 1
                    out[i] = out[i + 1] = " "
                    i += 2
                    continue
                if source.startswith("*/", i):
                    depth -= 1
                    out[i] = out[i + 1] = " "
                    i += 2
                    continue
                if source[i] != "\n":
                    out[i] = " "
                i += 1
            continue
        if ch in "'\"":
            triple = source.startswith(ch * 3, i)
            quote = ch * 3 if triple else ch
            i += len(quote)
            while i < n and not source.startswith(quote, i):
                if source[i] == "\\":
                    out[i] = " "
                    i += 1
                    if i < n:
                        if source[i] != "\n":
                            out[i] = " "
                        i += 1
                    continue
                if source[i] != "\n":
                    out[i] = " "
                i += 1
            i += len(quote)
            continue
        i += 1
    return "".join(out)


def line_of(source, index):
    return source.count("\n", 0, index) + 1


def relative(path):
    return os.path.relpath(path, MOBILE_ROOT)


def find_in_source(raw):
    """Offsets of every guard anti-pattern hit in one file's raw source."""
    blanked = blank_comments_and_strings(raw)
    return [match.start() for match in GUARD_ANTIPATTERN.finditer(blanked)]


def dart_sources():
    """Every non-generated Dart file under lib/, following symlinks.

    `followlinks=True` walks the `lib/features/*` symlinks into
    `retired_sprawl/`, so the analyzer-excluded (but shipped and tested) tree is
    covered. Deduped by realpath so a file reached through a symlink is not
    scanned twice.
    """
    seen = set()
    files = []
    for root, dirs, names in os.walk(LIB_ROOT, followlinks=True):
        dirs[:] = sorted(dirs)
        for name in sorted(names):
            if not name.endswith(".dart") or name.endswith(".g.dart"):
                continue
            path = os.path.realpath(os.path.join(root, name))
            if path in seen:
                continue
            seen.add(path)
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    raw = handle.read()
            except (OSError, UnicodeDecodeError):
                continue
            files.append((path, raw))
    return files


# --------------------------------------------------------------------------
# Self-test — pin the matcher before trusting it on the tree.
# --------------------------------------------------------------------------

SELF_TEST_POSITIVE = {
    "single-line guard": "if (ctx.error! != null) {",
    "equality guard": "if (ctx.returnLoopPayoff! == null) {",
    "member chain": "if (ctx.whatChangedV2Display! != null) ...[",
    "wrapped over two lines": (
        "if (ctx.proUnderstandingLiftPostSaveResult! !=\n"
        "        null) ...["
    ),
    "indexed operand": "if (list[0]! != null) {",
    "call operand": "if (build()! != null) {",
}

SELF_TEST_NEGATIVE = {
    "correct guard": "if (ctx.error != null) {",
    "correct equality": "if (ctx.returnLoopPayoff == null) {",
    "prefix logical-not": "if (!flag == expected) {",
    "assertion then use": "final v = ctx.error!;",
    "assertion far from compare": "if (a! + b != null) {",
    "plain not-equal": "if (a != null) {",
    "inside a string": "final s = 'ctx.error! != null';",
    "inside a line comment": "// legacy shape: ctx.error! != null",
}


def self_test():
    failures = []
    for label, snippet in SELF_TEST_POSITIVE.items():
        if not find_in_source(snippet):
            failures.append("MISS (should flag): %s -> %r" % (label, snippet))
    for label, snippet in SELF_TEST_NEGATIVE.items():
        if find_in_source(snippet):
            failures.append("FALSE POSITIVE: %s -> %r" % (label, snippet))
    for failure in failures:
        print("self-test %s" % failure)
    if failures:
        return 1
    print(
        "self-test ok: %d anti-pattern shapes flagged, %d look-alikes "
        "(correct guards, prefix-not, body assertions, strings, comments) "
        "stayed quiet" % (len(SELF_TEST_POSITIVE), len(SELF_TEST_NEGATIVE))
    )
    return 0


def main():
    if self_test():
        return 1
    if "--self-test" in sys.argv:
        return 0

    files = dart_sources()
    violations = []
    for path, raw in files:
        for offset in find_in_source(raw):
            violations.append((relative(path), line_of(raw, offset)))

    if not violations:
        print(
            "no `X! != null` / `X! == null` null-check-operator guards found "
            "(%d dart files scanned, including analyzer-excluded "
            "retired_sprawl symlinks)" % len(files)
        )
        return 0

    print(
        "null-check-operator anti-pattern found — `!` inside a null guard throws"
        "\n`Null check operator used on a null value` when the operand is null:\n"
    )
    for path, line in sorted(set(violations)):
        print("  %s:%d" % (path, line))
    print(
        "\n%d occurrence(s). Drop the `!` from the guard condition"
        "\n(`if (x.field != null)`); keep `x.field!` in the block body, where the"
        "\nvalue is already proven non-null. These files are excluded from"
        "\n`flutter analyze` (lib/features/** -> retired_sprawl) but still ship"
        "\nand run under test, so the analyzer never catches this."
        % len(set(violations))
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())

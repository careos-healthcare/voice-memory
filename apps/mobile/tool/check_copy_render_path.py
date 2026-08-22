#!/usr/bin/env python3
"""Fail when a privacy/trust copy constant has no live render path.

A security or privacy document that cites a user-facing string as evidence is
offering a reviewer something they can check by using the app. That stops being
true the moment the only widget reading the string is one nothing constructs:
the promise is still in the source, still greppable, still quoted in review —
and no user can reach it. `CaregiverCopy.dashboardSubtitle` is the worked
example. It says which surfaces this device refuses while a caregiver session
is active, it is cited as evidence in
`docs/security/CAREGIVER_ACCESS_PRELAUNCH_BLOCKERS.md`, and its sole reader is
`CaregiverDashboardView`, which nothing builds and no route reaches.

Scope is deliberately the privacy copy scanner's own discovery set rather than
all copy in the tree. `PrivacyCopyPolicy.isConsumerPrivacySource` is read out of
`lib/security/privacy_copy_policy.dart` at run time — both the pattern and the
explicit source list — so this gate and
`tool/privacy/check_privacy_copy_policy.dart` cannot drift into disagreeing
about what counts as a privacy surface. Gating all copy would be a much larger
report and would never land.

A member is LIVE when any of these holds:

  * a `lib/` file that is not a `*_copy.dart` reads it from code, and the class
    enclosing that read is either not a widget or is a widget with at least one
    construction site in `lib/`;
  * a live member's initializer references it. Aggregates (`PrivacyScreenCopy.
    sections`, `OnDeviceHeroCopy.pillars`) and cross-class aliases
    (`pillarRemoteTitle = OnDeviceArchitectureCopy.remoteHeading`) both travel
    this edge, to a fixpoint.

Everything else is reported: members whose only readers are copy files, test
files (never walked — only `lib/` is), or widget classes with no construction
site.

Three method bugs sank an earlier hand-audit of this exact question, which
reported 1,623 dead constants and walked it back to 263 as each was fixed. All
three are modelled here and pinned by the self-test:

  1,623 -> 612  Same-file aggregates. `PrivacyScreenCopy.sections` renders six
                title/body pairs that a name scan sees as unread. Handled by
                the initializer edge above.
    612 -> 605  Record types. `static const List<({String title, String body})>
                pillars` did not parse, so four live onboarding trust pillars
                looked dead. The declaration reader scans to the assignment at
                bracket depth zero instead of matching a type grammar, so the
                nested `(` and `{` inside the generic cost it nothing.
    605 -> 263  File-level reader attribution. One never-constructed private
                helper in a live screen made every string in that screen look
                dead. Readers are attributed to the enclosing *class*, and a
                private helper built by its own screen (`_ControlCallout()` in
                `caregiver_access_screen.dart`) counts as constructed.

A `State` subclass is resolved to the widget it is the state for: every
`_FooState` is constructed by its own `createState`, so asking whether
`_FooState` is built answers nothing. `_CaregiverDashboardViewState` is live
only if `CaregiverDashboardView` is built somewhere, and it is not.

DIRECTION OF ERROR: this errs toward FALSE NEGATIVES, matching
`check_initstate_provider_writes.py`. Reads through an import prefix, a
`C.new` tear-off, reflection, or a string-keyed lookup are all missed; widget
construction is checked one level deep rather than transitively, so two dead
widgets that build each other both read as live; and any read from a non-copy
file that is not inside a widget counts. A guard that fires on live copy gets
switched off in a week, and a quiet guard that stays on is worth more than a
complete one that does not.

Walks `lib/` with `followlinks=True` and deduplicates by realpath: 373 of the
387 entries under `lib/features/` are symlinks into `retired_sprawl/`, which
`analysis_options.yaml` excludes but the app still compiles and ships. Neither
the analyzer nor a non-following walk sees that code.

Usage (from apps/mobile):
  python3 tool/check_copy_render_path.py                  # gate
  python3 tool/check_copy_render_path.py --report         # every dead member
  python3 tool/check_copy_render_path.py --write-baseline
  python3 tool/check_copy_render_path.py --self-test

Exit codes: 0 clean, 1 new dead constant or failed self-test, 2 bad usage.
"""

import os
import re
import sys

MOBILE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB_ROOT = os.path.join(MOBILE_ROOT, "lib")
POLICY_PATH = os.path.join(MOBILE_ROOT, "lib", "security", "privacy_copy_policy.dart")
BASELINE_PATH = os.path.join(MOBILE_ROOT, "tool", "copy_render_path_baseline.txt")

POLICY_SELF_PATH = "lib/security/privacy_copy_policy.dart"

CLASS_DECL = re.compile(r"\bclass\s+(\w+)\b")
STATIC_DECL = re.compile(r"\bstatic\b")
IDENTIFIER = re.compile(r"[A-Za-z_]\w*")
DOT_MEMBER = re.compile(r"\.\s*([A-Za-z_]\w*)")
BARE_REF = re.compile(r"(?<![\w.$'\"])([A-Za-z_]\w*)\b")
EXTENDS = re.compile(r"\bextends\s+([\w$]+)\s*(?:<\s*([\w$]+))?")
IDENTIFIER_CHAIN = re.compile(r"^[A-Za-z_]\w*(?:\s*\.\s*[A-Za-z_]\w*)*$")

# `extends State<Foo>` / `extends ConsumerState<Foo>`: the state object is
# always constructed by its own widget's `createState`, so its liveness is the
# widget's liveness, never its own.
STATE_SUPERCLASSES = {"State", "ConsumerState"}

WIDGET_SUPERCLASS = re.compile(r"Widget$|^State$|^ConsumerState$")


# --------------------------------------------------------------------------
# Lexing. Same approach as tool/check_initstate_provider_writes.py, vendored
# rather than imported so a change to that gate cannot break this one.
# --------------------------------------------------------------------------

def blank_comments_and_strings(source):
    """Replace comment and string *contents* with spaces, preserving offsets.

    Quote characters survive, so an initializer can still be recognised as a
    string literal after blanking.
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


def match_bracket(source, open_index):
    """Index just past the bracket closing the one at `open_index`."""
    pairs = {"{": "}", "(": ")", "[": "]"}
    opener = source[open_index]
    closer = pairs[opener]
    depth = 0
    for i in range(open_index, len(source)):
        if source[i] == opener:
            depth += 1
        elif source[i] == closer:
            depth -= 1
            if depth == 0:
                return i + 1
    return len(source)


def identifier_before(source, dot_index):
    """The identifier immediately left of the dot at `dot_index`, or None."""
    i = dot_index - 1
    while i >= 0 and source[i] in " \t\n":
        i -= 1
    end = i + 1
    while i >= 0 and (source[i].isalnum() or source[i] == "_"):
        i -= 1
    if i + 1 == end:
        return None
    name = source[i + 1:end]
    return name if (name[0].isalpha() or name[0] == "_") else None


def class_bodies(source):
    """Yield (name, header, body_open, body_end) for every class in `source`."""
    for match in CLASS_DECL.finditer(source):
        brace = source.find("{", match.end())
        if brace < 0:
            continue
        header = source[match.end():brace]
        if ";" in header:  # `class X = A with B;`
            continue
        yield match.group(1), header, brace, match_bracket(source, brace)


# --------------------------------------------------------------------------
# Scope — mirrors PrivacyCopyPolicy.isConsumerPrivacySource by reading it
# --------------------------------------------------------------------------

def load_privacy_scope(policy_source):
    """Extract the surface pattern and explicit source list from the policy.

    Read rather than re-declared: a copy of the list here would drift from the
    Dart one silently, and the whole point of scoping to the privacy scanner is
    that the two agree about what a privacy surface is.
    """
    pattern = re.search(
        r"_surfacePathPattern\s*=\s*RegExp\(\s*'([^']+)'", policy_source
    )
    listing = re.search(
        r"consumerPrivacySources\s*=\s*\[(.*?)\];", policy_source, re.S
    )
    if pattern is None or listing is None:
        raise SystemExit(
            "could not read PrivacyCopyPolicy scope out of %s — this gate "
            "derives its scan set from that file so the two cannot disagree"
            % POLICY_SELF_PATH
        )
    explicit = frozenset(re.findall(r"'([^']+)'", listing.group(1)))
    return re.compile(pattern.group(1), re.IGNORECASE), explicit


def is_consumer_privacy_source(rel_path, surface_pattern, explicit):
    normalized = rel_path.replace("\\", "/")
    if not normalized.endswith(".dart"):
        return False
    if not normalized.startswith("lib/"):
        return False
    if normalized == POLICY_SELF_PATH:
        return False
    if normalized.endswith("_copy.dart"):
        return True
    if normalized in explicit:
        return True
    return bool(surface_pattern.search(normalized))


# --------------------------------------------------------------------------
# Declarations
# --------------------------------------------------------------------------

class Member:
    def __init__(
        self, path, cls, name, line, type_text, init_start, init_end, declaration,
        decl_start,
    ):
        self.path = path
        self.cls = cls
        self.name = name
        self.line = line
        # Offset of the `static` keyword, so the declaration's own name can be
        # told apart from a genuine read of it earlier in the class body.
        self.decl_start = decl_start
        self.type_text = type_text
        self.init_start = init_start
        self.init_end = init_end
        # False for a static getter or method: it carries references but is not
        # itself a string anyone was shown, so it is never reported.
        self.declaration = declaration
        self.reported = False

    @property
    def key(self):
        return "%s %s.%s" % (self.path, self.cls, self.name)

    def __repr__(self):
        return "%s:%d %s.%s" % (self.path, self.line, self.cls, self.name)


def find_assignment(source, start, limit):
    """Index of the `=` that opens an initializer, or None.

    Scans at bracket depth zero so a record type in the generic —
    `List<({String title, String body})>` — costs nothing. Returns None for a
    method (`=>` or a `(` parameter list at depth zero) and for a bare
    declaration with no initializer.
    """
    depth = 0
    i = start
    while i < limit:
        ch = source[i]
        if ch in "<([{":
            depth += 1
        elif ch in ">)]}":
            depth -= 1
            if depth < 0:
                return None
        elif ch == ";" and depth == 0:
            return None
        elif ch == "=" and depth == 0:
            if source[i + 1:i + 2] == ">":     # fat arrow: a method
                return None
            if source[i + 1:i + 2] == "=":     # ==
                return None
            if source[i - 1:i] in ("!", "<", ">", "="):
                i += 1
                continue
            return i
        i += 1
    return None


def statement_end(source, start, limit):
    depth = 0
    i = start
    while i < limit:
        ch = source[i]
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == ";" and depth == 0:
            return i
        i += 1
    return limit


def find_body(source, start, limit):
    """Locate a static getter's or method's body — `(head_end, from, to)`.

    A copy class states an aggregate two ways: as a `static const` list, and as
    a `static ... get name => [a, b, c];`. Only the first is a declaration with
    an initializer, so a reader that models fields alone sees every member of
    the second kind as unread. `ArchivePaywallCopy.purchaseConfidenceCopy` is
    that shape and it renders four live strings.
    """
    depth = 0
    i = start
    while i < limit:
        ch = source[i]
        if ch == "{" and depth == 0:
            return (i, i, match_bracket(source, i))
        if ch in "<([{":
            depth += 1
        elif ch in ">)]}":
            depth -= 1
            if depth < 0:
                return None
        elif ch == ";" and depth == 0:
            return None
        elif ch == "=" and depth == 0 and source[i + 1:i + 2] == ">":
            return (i, i + 2, statement_end(source, i + 2, limit))
        i += 1
    return None


def name_before(head):
    """The declared name in `head`, ignoring a trailing parameter list."""
    text = head.rstrip()
    if text.endswith(")"):
        opener = text.rfind("(")
        while opener > 0 and text.count("(", opener) != text.count(")", opener):
            opener = text.rfind("(", 0, opener)
        if opener < 0:
            return None, ""
        text = text[:opener].rstrip()
    last = None
    for last in IDENTIFIER.finditer(text):
        pass
    if last is None:
        return None, ""
    return last.group(0), text[:last.start()].strip()


def parse_members(path, blanked, line_index):
    """Static declarations by class: fields first, then getters and methods.

    Getters and methods are parsed as members with their body standing in for
    an initializer. They are never *reported* — a method is not a promise — but
    they carry references, so an aggregate expressed as a getter propagates
    liveness exactly the way a `static const` list does.
    """
    members = []
    for cls, _header, body_open, body_end in class_bodies(blanked):
        for match in STATIC_DECL.finditer(blanked, body_open, body_end):
            assign = find_assignment(blanked, match.end(), body_end)
            if assign is not None:
                head = blanked[match.end():assign]
                name, type_text = name_before(head)
                if name is None:
                    continue
                members.append(
                    Member(
                        path=path,
                        cls=cls,
                        name=name,
                        line=line_index(match.start()),
                        type_text=type_text,
                        init_start=assign + 1,
                        init_end=statement_end(blanked, assign + 1, body_end),
                        declaration=True,
                        decl_start=match.start(),
                    )
                )
                continue

            body = find_body(blanked, match.end(), body_end)
            if body is None:
                continue
            head_end, body_start, body_end_index = body
            name, _type_text = name_before(blanked[match.end():head_end])
            if name is None:
                continue
            members.append(
                Member(
                    path=path,
                    cls=cls,
                    name=name,
                    line=line_index(match.start()),
                    type_text="",
                    init_start=body_start,
                    init_end=body_end_index,
                    declaration=False,
                    decl_start=match.start(),
                )
            )
    return members


def is_copy_shaped(member, blanked):
    """Whether a declaration carries user-facing words rather than plumbing.

    Keys, durations, colours and numbers are still parsed — they can appear in
    an aggregate — but they are never *reported*, because a dead `Key` constant
    is not a promise anyone was shown.
    """
    if "String" in member.type_text:
        return True
    initializer = blanked[member.init_start:member.init_end].strip()
    if initializer[:1] in ("'", '"'):
        return True
    # `static const a = Other.b;` — an alias into another copy class.
    return bool(IDENTIFIER_CHAIN.match(initializer))


# --------------------------------------------------------------------------
# Classes and construction
# --------------------------------------------------------------------------

class ClassSpan:
    def __init__(self, path, name, header, start, end):
        self.path = path
        self.name = name
        self.header = header
        self.start = start
        self.end = end

    @property
    def widget_liveness_target(self):
        """Which class name must be constructed for this one to render.

        For a `State` subclass that is the widget it serves, because a state
        object is always built by its own widget's `createState` — checking the
        state class itself would answer a question nobody asked. Returns None
        when the class is not a widget at all, which means "no construction
        required".
        """
        extends = EXTENDS.search(self.header)
        if extends is None:
            return None
        base = extends.group(1)
        if base in STATE_SUPERCLASSES:
            return extends.group(2) or self.name
        if WIDGET_SUPERCLASS.search(base):
            return self.name
        return None


def collect_construction_sites(files, class_spans_by_name, members):
    """Class names built at least once from `lib/`.

    A build inside the class's own body is ignored, because a constructor
    declaration (`const CaregiverDashboardView({...})`) is not a construction
    site — unless it sits inside a *static* member of that class. That is the
    `static Future<bool> show(context) => showModalBottomSheet(builder: (_) =>
    PostSaveMomentDetailSheet(...))` idiom, where the class really is built and
    the caller is one hop further out. Counting it can only make this gate
    quieter, which is the direction it is tuned in.
    """
    constructed = set()
    own_spans = {}
    for name, spans in class_spans_by_name.items():
        own_spans[name] = [(span.path, span.start, span.end) for span in spans]

    static_spans = {}
    for member in members:
        static_spans.setdefault((member.path, member.cls), []).append(
            (member.init_start, member.init_end)
        )

    for path, _raw, blanked, _line_index in files:
        for match in re.finditer(r"\b([A-Za-z_]\w*)\s*\(", blanked):
            name = match.group(1)
            if name in constructed or name not in own_spans:
                continue
            at = match.start()
            inside_own_body = any(
                span_path == path and start <= at < end
                for span_path, start, end in own_spans[name]
            )
            if inside_own_body:
                in_static_member = any(
                    start <= at < end
                    for start, end in static_spans.get((path, name), ())
                )
                if not in_static_member:
                    continue
            constructed.add(name)
    return constructed


# --------------------------------------------------------------------------
# Analysis
# --------------------------------------------------------------------------

def analyse(files, surface_pattern, explicit):
    members = []
    class_spans_by_name = {}
    spans_by_path = {}

    for path, _raw, blanked, line_index in files:
        members += parse_members(path, blanked, line_index)
        spans = []
        for name, header, body_open, body_end in class_bodies(blanked):
            span = ClassSpan(path, name, header, body_open, body_end)
            spans.append(span)
            class_spans_by_name.setdefault(name, []).append(span)
        spans_by_path[path] = spans

    blanked_by_path = {path: blanked for path, _raw, blanked, _index in files}
    for member in members:
        member.reported = (
            member.declaration
            and is_consumer_privacy_source(member.path, surface_pattern, explicit)
            and is_copy_shaped(member, blanked_by_path[member.path])
        )

    by_class_name = {}
    for member in members:
        by_class_name.setdefault((member.cls, member.name), []).append(member)
    class_member_names = {}
    for member in members:
        class_member_names.setdefault(member.cls, set()).add(member.name)

    constructed = collect_construction_sites(files, class_spans_by_name, members)

    # Initializer spans, so a reference inside one becomes a graph edge rather
    # than a render site.
    inits_by_path = {}
    for member in members:
        inits_by_path.setdefault(member.path, []).append(member)

    edges = {}       # member key -> set of member keys it references
    rendered = set() # member keys with a real render site
    evidence = {}    # member key -> why it is dead

    def enclosing_member(path, at):
        for candidate in inits_by_path.get(path, ()):
            if candidate.init_start <= at < candidate.init_end:
                return candidate
        return None

    def enclosing_class(path, at):
        best = None
        for span in spans_by_path.get(path, ()):
            if span.start <= at < span.end:
                if best is None or span.start > best.start:
                    best = span
        return best

    def note_reference(target_key, path, at):
        source_member = enclosing_member(path, at)
        if source_member is not None:
            # Inside another member's initializer or getter body. This is the
            # edge that carries aggregates and aliases — and it is also what
            # stops a copy file laundering liveness, precisely rather than by
            # file name: the alias only confers liveness if the aliasing
            # member is itself reachable.
            if source_member.key != target_key:
                edges.setdefault(source_member.key, set()).add(target_key)
            return
        span = enclosing_class(path, at)
        if span is not None:
            required = span.widget_liveness_target
            if required is not None and required not in constructed:
                evidence.setdefault(target_key, set()).add(
                    "read in %s (%s is never constructed in lib/)"
                    % (span.name, required)
                )
                return
        rendered.add(target_key)

    for path, _raw, blanked, _line_index in files:
        # Scanned per dot rather than with one `Class.member` pattern, because
        # a non-overlapping match on `prefix.Class.member` consumes
        # `prefix.Class` and never sees `Class.member`. 64 files import with an
        # `as` prefix, so that gap would invent dead constants.
        for match in DOT_MEMBER.finditer(blanked):
            name = match.group(1)
            cls = identifier_before(blanked, match.start())
            if cls is None:
                continue
            for member in by_class_name.get((cls, name), ()):
                note_reference(member.key, path, match.start())

        # Bare references inside the declaring class body — how an aggregate
        # names its members and how a class reads its own copy.
        for span in spans_by_path.get(path, ()):
            names = class_member_names.get(span.name)
            if not names:
                continue
            body = blanked[span.start:span.end]
            for match in BARE_REF.finditer(body):
                name = match.group(1)
                if name not in names:
                    continue
                at = span.start + match.start()
                for member in by_class_name.get((span.name, name), ()):
                    if (
                        member.path == path
                        and member.decl_start <= at < member.init_start
                    ):
                        continue  # the declaration's own name
                    note_reference(member.key, path, at)

    live = set(rendered)
    changed = True
    while changed:
        changed = False
        for source_key in list(live):
            for target in edges.get(source_key, ()):
                if target not in live:
                    live.add(target)
                    changed = True

    dead = [m for m in members if m.reported and m.key not in live]
    dead.sort(key=lambda m: (m.path, m.cls, m.name))
    return dead, evidence, len(members), len(constructed)


# --------------------------------------------------------------------------
# I/O
# --------------------------------------------------------------------------

def make_line_index(raw):
    return lambda index: raw.count("\n", 0, index) + 1


def dart_sources():
    """Every Dart file under `lib/`, following symlinks, deduped by realpath."""
    files = []
    seen = set()
    for root, dirs, names in os.walk(LIB_ROOT, followlinks=True):
        dirs[:] = sorted(dirs)
        for name in sorted(names):
            if not name.endswith(".dart") or name.endswith(".g.dart"):
                continue
            full = os.path.join(root, name)
            real = os.path.realpath(full)
            if real in seen:
                continue
            seen.add(real)
            try:
                with open(real, "r", encoding="utf-8") as handle:
                    raw = handle.read()
            except (OSError, UnicodeDecodeError):
                continue
            rel = os.path.relpath(full, MOBILE_ROOT).replace("\\", "/")
            files.append((rel, raw, blank_comments_and_strings(raw), make_line_index(raw)))
    return files


def read_baseline():
    if not os.path.exists(BASELINE_PATH):
        return set()
    with open(BASELINE_PATH, "r", encoding="utf-8") as handle:
        return {
            line.strip()
            for line in handle
            if line.strip() and not line.startswith("#")
        }


def write_baseline(dead):
    with open(BASELINE_PATH, "w", encoding="utf-8") as handle:
        handle.write(
            "# Copy constants with no live render path, as of the day this gate\n"
            "# landed. Each line is a promise that is still in the source and\n"
            "# still citable in review, and that no user can reach.\n"
            "#\n"
            "# This is debt, not permission. Give one a render path or delete\n"
            "# it, then drop the line. Regenerate with:\n"
            "#   python3 tool/check_copy_render_path.py --write-baseline\n"
            "#\n"
        )
        for member in dead:
            handle.write("%s\n" % member.key)


# --------------------------------------------------------------------------
# Self-test
# --------------------------------------------------------------------------

# Every shape this gate has to get right. The first three are the defect it was
# written for; the rest are the look-alikes it must stay quiet about, one for
# each of the three method bugs that sank the hand-audit.
SELF_TEST_SOURCES = {
    # A privacy source by name (`_copy.dart`), so its members are in scope.
    "lib/features/caregiver/caregiver_copy.dart": """
      abstract final class CaregiverCopy {
        static const dashboardTitle = 'Caregiver monitoring';
        static const dashboardSubtitle =
            'On this device, recording, exporting and playing back the '
            'original audio are refused while this session is active.';
        static const verificationFailedMessage =
            'Consent token could not be verified.';
        static const orphanNobodyReads = 'Nothing reads this at all.';
      }
    """,
    # Never constructed, so nothing it renders is reachable.
    "lib/features/caregiver/caregiver_dashboard_view.dart": """
      class CaregiverDashboardView extends StatefulWidget {
        const CaregiverDashboardView({super.key});

        @override
        State<CaregiverDashboardView> createState() =>
            _CaregiverDashboardViewState();
      }

      class _CaregiverDashboardViewState extends State<CaregiverDashboardView> {
        @override
        Widget build(BuildContext context) {
          return Column(children: [
            Text(CaregiverCopy.dashboardTitle),
            Text(CaregiverCopy.dashboardSubtitle),
            Text(CaregiverCopy.verificationFailedMessage),
          ]);
        }
      }
    """,
    "lib/features/settings/caregiver_access_copy.dart": """
      abstract final class CaregiverAccessCopy {
        static const intentHeading = 'Limits this device enforces';
        static const intentBody =
            'On this device, exporting and recording are blocked.';
        static const calloutBody = 'Only you can grant access.';
        static const Key screenKey = Key('caregiver_access');
      }
    """,
    # Routed, so what it builds renders. `_ControlCallout` is the private
    # helper shape that file-level attribution got wrong: never constructed
    # anywhere but here, and perfectly live.
    "lib/features/settings/caregiver_access_screen.dart": """
      class CaregiverAccessScreen extends StatelessWidget {
        const CaregiverAccessScreen({super.key});

        @override
        Widget build(BuildContext context) {
          return ListView(children: const [
            _ControlCallout(),
            Text(CaregiverAccessCopy.intentHeading),
            Text(CaregiverAccessCopy.intentBody),
          ]);
        }
      }

      class _ControlCallout extends StatelessWidget {
        const _ControlCallout();

        @override
        Widget build(BuildContext context) {
          return Text(CaregiverAccessCopy.calloutBody);
        }
      }
    """,
    "lib/router/app_router.dart": """
      final router = GoRouter(routes: [
        GoRoute(
          path: '/caregiver-access',
          builder: (context, state) => const CaregiverAccessScreen(),
        ),
        GoRoute(
          path: '/privacy',
          builder: (context, state) => const PrivacyScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnDeviceHeroScreen(),
        ),
        GoRoute(
          path: '/consent-status',
          builder: (context, state) => const ConsentStatusBanner(),
        ),
      ]);
    """,
    # Aggregate shape: nothing names these members except `sections`.
    "lib/features/trust/privacy_screen_copy.dart": """
      abstract final class PrivacyScreenCopy {
        static const onDeviceTitle = 'Stays on your device';
        static const onDeviceBody = 'Recordings never leave unless you ask.';
        static const retiredTitle = 'No longer shown anywhere';
        static const List<PrivacySection> sections = [
          PrivacySection(title: onDeviceTitle, body: onDeviceBody),
        ];
      }
    """,
    "lib/screens/privacy_screen.dart": """
      class PrivacyScreen extends StatelessWidget {
        const PrivacyScreen({super.key});

        @override
        Widget build(BuildContext context) {
          return ListView(
            children: [
              for (final section in PrivacyScreenCopy.sections)
                Text(section.title),
            ],
          );
        }
      }
    """,
    # Record type in the generic, plus a cross-file alias.
    "lib/features/onboarding/on_device_hero_copy.dart": """
      abstract final class OnDeviceHeroCopy {
        static const String pillarLocalTitle = 'Processed on this device';
        static const String pillarLocalBody = 'Nothing is uploaded to score it.';
        static const String pillarRemoteTitle =
            OnDeviceArchitectureCopy.remoteHeading;
        static const List<({String title, String body})> pillars = [
          (title: pillarLocalTitle, body: pillarLocalBody),
          (title: pillarRemoteTitle, body: pillarLocalBody),
        ];
      }
    """,
    "lib/features/onboarding/on_device_architecture_copy.dart": """
      abstract final class OnDeviceArchitectureCopy {
        static const String remoteHeading = 'When something is sent out';
      }
    """,
    # The `static show()` idiom: the sheet is only ever built inside its own
    # class body, by a static helper the caller reaches instead. Treating the
    # constructor declaration and this as the same thing would report every
    # string on a live bottom sheet.
    "lib/features/consent/consent_sheet_copy.dart": """
      abstract final class ConsentSheetCopy {
        static const String sheetTitle = 'Share what, exactly?';
      }
    """,
    "lib/features/consent/consent_sheet.dart": """
      class ConsentSheet extends StatefulWidget {
        const ConsentSheet({super.key});

        static Future<bool?> show(BuildContext context) {
          return showModalBottomSheet<bool>(
            context: context,
            builder: (sheetContext) => const ConsentSheet(),
          );
        }

        @override
        State<ConsentSheet> createState() => _ConsentSheetState();
      }

      class _ConsentSheetState extends State<ConsentSheet> {
        @override
        Widget build(BuildContext context) {
          return Text(ConsentSheetCopy.sheetTitle);
        }
      }
    """,
    # An aggregate stated as a getter rather than a `static const` list, and a
    # sibling read only through an import prefix. Both look dead to a reader
    # that models fields only, or that matches `Class.member` non-overlapping.
    "lib/features/trust/consent_status_copy.dart": """
      abstract final class ConsentStatusCopy {
        static const String checkingAccess = 'Checking your access…';
        static const String accessRestored = 'Access restored.';
        static const String prefixedOnly = 'Reached through a prefixed import.';
        static const String neverNamed = 'No reader of any kind.';

        static List<String> get progressCopy => [
              checkingAccess,
              accessRestored,
            ];
      }
    """,
    "lib/features/trust/consent_status_banner.dart": """
      import 'consent_status_copy.dart' as copy;

      class ConsentStatusBanner extends StatelessWidget {
        const ConsentStatusBanner({super.key});

        @override
        Widget build(BuildContext context) {
          return Column(children: [
            for (final line in ConsentStatusCopy.progressCopy) Text(line),
            Text(copy.ConsentStatusCopy.prefixedOnly),
          ]);
        }
      }
    """,
    "lib/features/onboarding/on_device_hero_screen.dart": """
      class OnDeviceHeroScreen extends StatelessWidget {
        const OnDeviceHeroScreen({super.key});

        @override
        Widget build(BuildContext context) {
          return Column(
            children: [
              for (final pillar in OnDeviceHeroCopy.pillars) Text(pillar.title),
            ],
          );
        }
      }
    """,
}

# Dead: read only by a never-constructed widget, or read by nothing.
SELF_TEST_EXPECTED = {
    "lib/features/caregiver/caregiver_copy.dart CaregiverCopy.dashboardTitle",
    "lib/features/caregiver/caregiver_copy.dart CaregiverCopy.dashboardSubtitle",
    "lib/features/caregiver/caregiver_copy.dart CaregiverCopy.verificationFailedMessage",
    "lib/features/caregiver/caregiver_copy.dart CaregiverCopy.orphanNobodyReads",
    "lib/features/trust/privacy_screen_copy.dart PrivacyScreenCopy.retiredTitle",
    "lib/features/trust/consent_status_copy.dart ConsentStatusCopy.neverNamed",
}


def self_test():
    files = []
    for path, source in SELF_TEST_SOURCES.items():
        files.append(
            (path, source, blank_comments_and_strings(source), make_line_index(source))
        )

    surface_pattern = re.compile(
        "privacy|trust|consent|security|onboarding", re.IGNORECASE
    )
    dead, _evidence, parsed, constructed = analyse(files, surface_pattern, frozenset())
    found = {member.key for member in dead}

    problems = []
    for missing in sorted(SELF_TEST_EXPECTED - found):
        problems.append("MISS: %s" % missing)
    for spurious in sorted(found - SELF_TEST_EXPECTED):
        problems.append("FALSE POSITIVE: %s" % spurious)

    # The record-type declaration has to have parsed at all: if the generic
    # `List<({String title, String body})>` defeats the reader then `pillars`
    # is invisible, and the two pillars it renders look dead for the wrong
    # reason. Asserting the members are quiet only proves this when the
    # aggregate is the sole thing naming them, which it is above.
    record_aggregate = (
        "lib/features/onboarding/on_device_hero_copy.dart OnDeviceHeroCopy.pillars"
    )
    if record_aggregate in found:
        problems.append("FALSE POSITIVE: record-type aggregate read as dead")

    for entry in problems:
        print("self-test %s" % entry)
    if problems:
        return 1
    print(
        "self-test ok: %d dead shapes flagged; same-file aggregates, "
        "record-type generics, cross-file aliases, private helper widgets and "
        "routed screens all stayed quiet (%d members, %d classes constructed)"
        % (len(found), parsed, constructed)
    )
    return 0


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------

def main(argv):
    known = {"--report", "--write-baseline", "--self-test"}
    unknown = [arg for arg in argv[1:] if arg not in known]
    if unknown:
        sys.stderr.write("unknown arguments: %s\n" % " ".join(unknown))
        return 2

    # The gate is only as good as its own matching rules, so pin them first.
    if self_test():
        return 1
    if "--self-test" in argv:
        return 0

    if not os.path.isdir(LIB_ROOT):
        sys.stderr.write("run this from apps/mobile — no lib directory here\n")
        return 2

    with open(POLICY_PATH, "r", encoding="utf-8") as handle:
        surface_pattern, explicit = load_privacy_scope(handle.read())

    files = dart_sources()
    dead, evidence, parsed, constructed = analyse(files, surface_pattern, explicit)

    in_scope = sum(
        1
        for path, _raw, _blanked, _index in files
        if is_consumer_privacy_source(path, surface_pattern, explicit)
    )

    if "--write-baseline" in argv:
        write_baseline(dead)
        print(
            "wrote %d dead copy constants to %s"
            % (len(dead), os.path.relpath(BASELINE_PATH, MOBILE_ROOT))
        )
        return 0

    baseline = read_baseline()
    new = [member for member in dead if member.key not in baseline]
    produced = {member.key for member in dead}
    stale = sorted(entry for entry in baseline if entry not in produced)

    print(
        "scanned %d dart files under lib/ (%d privacy/trust sources, %d static "
        "declarations, %d classes constructed) — %d copy constants with no "
        "render path, %d new"
        % (len(files), in_scope, parsed, constructed, len(dead), len(new))
    )

    if "--report" in argv:
        for member in dead:
            flag = "NEW " if member.key not in baseline else ""
            print("  %s%s:%d %s.%s" % (flag, member.path, member.line, member.cls, member.name))
            for reason in sorted(evidence.get(member.key, ())):
                print("      %s" % reason)

    if stale:
        # Reported, never fatal. Ten agents write this tree at once and a
        # constant deleted by one of them would otherwise fail the gate for
        # everyone else; a gate that fails for reasons the reader did not cause
        # is a gate that gets switched off.
        print(
            "\n%d baseline entries no longer produced (fixed or deleted). "
            "Regenerate with --write-baseline to shrink the baseline:" % len(stale)
        )
        for entry in stale[:20]:
            print("  %s" % entry)
        if len(stale) > 20:
            print("  ... and %d more" % (len(stale) - 20))

    if not new:
        print("OK — no copy constant newly lost its render path")
        return 0

    sys.stderr.write(
        "\nNEW copy constants with no live render path:\n"
    )
    for member in new:
        sys.stderr.write(
            "  %s:%d %s.%s\n" % (member.path, member.line, member.cls, member.name)
        )
        for reason in sorted(evidence.get(member.key, ())):
            sys.stderr.write("      %s\n" % reason)
    sys.stderr.write(
        "\n%d constant(s) that no user can reach. A privacy or security claim\n"
        "nobody can see is not a disclosure, and citing one as evidence offers\n"
        "a reviewer something they cannot check by using the app.\n"
        "\nFix: give it a render path, or delete it and stop citing it.\n"
        "If it is deliberately retired, run --write-baseline and say why in\n"
        "the change that adds the line.\n" % len(new)
    )
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))

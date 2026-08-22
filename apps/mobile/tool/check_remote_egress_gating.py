#!/usr/bin/env python3
"""Fail when user audio or transcript text can reach the network ungated.

`RemoteProcessingConsentGate.isPurposePermittedNow` is the authoritative
predicate for "may this leave the device?" — it composes per-purpose consent
with the "Never send to server" toggle and fails closed. The previous guard,
`test/privacy/remote_processing_consent_bypass_guard_test.dart`, asserted that
five *named* files still mentioned that class. The onboarding brain-dump
pipeline streamed raw PCM to a WebSocket and was not one of the five, so the
guard stayed green for the entire life of the leak. A hand-maintained list of
boundaries cannot fail on a boundary nobody added to it.

This one is told nothing. It finds the boundaries.

  Pass W  Discover the *wire primitives* — the shapes that actually put bytes
          on a socket — from the source itself:
            * `<x>.sink.add(...)`, the WebSocket send;
            * every method declared under a Retrofit write annotation
              (`@POST` / `@PUT` / `@PATCH`), so a new endpoint is picked up the
              moment it is declared;
            * every write method on the hand-rolled `HttpTransport`, read off
              that class rather than listed here.

  Pass E  Grow those into the set of *egress methods* by fixpoint over calls:
          a method that calls an egress method is one too. This is what walks
          `CaptureRepository.postTranscribe` out to its handlers, and
          `LiveAudioWebSocketClient.sendPcm16kChunk` out to whatever screen is
          holding the microphone. The set is then filtered to the methods that
          carry *user content*: a parameter or argument naming audio, PCM, a
          transcript, a vault, an utterance, a waveform, a brain dump. Metadata
          that merely travels alongside (`speechLocale`, `durationSeconds`,
          `captureToken`) is not content and does not pull a method in.

  Pass G  Discover the *gate consultations* the same way: the public methods of
          `RemoteProcessingConsentGate`, grown by fixpoint over delegation, so
          `CaptureProofAnalyzer.isPurposeGranted` and the
          `CapturePipelineMiddleware.isPurposeGranted` facade in front of it
          both count without being named here.

  Pass C  A class is *covered* when one of its methods consults the gate, or
          when every class that calls into it is covered. Solved as a greatest
          fixpoint: everything starts covered and coverage is withdrawn only on
          proof. A content-carrying wire site inside an uncovered class is a
          violation, reported with the uncovered call chain above it so the
          fix goes in at the right level.

DIRECTION OF ERROR: toward FALSE NEGATIVES, deliberately. Coverage is decided
per class, not per call, so a class that consults the gate anywhere is trusted
everywhere; receivers that cannot be resolved produce *extra* call edges rather
than fewer, which can only add coverage; content detection is lexical and will
miss a payload passed under a neutral name. A guard that shouts about the
`voice_capture_handler` path — which is gated, three facades up — is a guard
someone deletes. Silence on a real gap is recoverable; a disabled gate is not.

Like `check_initstate_provider_writes.py` this walks source with
`followlinks=True` and dedupes by realpath, because 373 of the 387 entries
under `lib/features/` are symlinks into the analyzer-excluded but very much
shipped `retired_sprawl/` tree. Anything driven by the analyzer is blind there.

Usage:
    python3 tool/check_remote_egress_gating.py [--self-test] [--inventory]
"""

import os
import re
import sys

MOBILE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB_ROOT = os.path.join(MOBILE_ROOT, "lib")

# --------------------------------------------------------------------------
# Allowlist
#
# An entry says "this content-carrying wire site is reachable without the gate
# and that is intended". Each needs a reason, and each must still match a real
# site: a stale entry fails the run, so the allowlist cannot quietly become the
# place where a boundary goes to be forgotten.
#
# Keys are "<path suffix>::<method>::<uncovered root class>". The root is the
# outermost ungated class on the path to the wire, so an entry excuses one
# known caller rather than the endpoint: wire up a second ungated route to the
# same endpoint and it appears as a root nobody has written down, and the run
# fails. Every violation prints the exact key it would need.
# --------------------------------------------------------------------------
EGRESS_ALLOWLIST = {
    # Not wired in production. `AppServices` builds the pipeline with
    # `LocalAiPipeline.heuristic(...)`, which leaves `_remoteFallback` null;
    # the only constructor that populates it, `LocalAiPipeline.create`, is
    # called from `test/features/reflections/local_ai_pipeline_test.dart` and
    # nowhere else. If it is ever wired it must be gated first — it would run
    # inside `_attemptLocalAiPipeline`, which `VoiceCaptureHandler.run` reaches
    # *before* its own consent check, so the audio would leave ahead of the
    # question being asked. Owned by the reflections agent; flagged, not fixed.
    "lib/api/retrofit/voice_memory_capture_api.dart::transcribe::"
    "LocalAiRemoteFallback":
        "no production wiring — heuristic() leaves the remote fallback null "
        "and create() is test-only; must be gated before it is wired",

    # Declared for a server capability the app does not use. Documented as such
    # in retired_sprawl/lib_features/trust/privacy_screen_copy.dart, and the
    # `ledger` field of VoiceMemoryRetrofitClient is never read.
    "lib/api/retrofit/voice_memory_ledger_api.dart::bulkImportMultipart::"
    "VoiceMemoryLedgerApi":
        "declaration only — the ledger API is constructed in the client "
        "bundle but never read by any caller",

    # Superseded. Vault recovery really goes out through
    # `HttpCaptureApiClient.postVaultRecovery` (multipart over HttpTransport),
    # which `OfflineVaultRecoveryService.recoverVault` gates. `LiveAudioRepository`
    # exposes only `mintSession`, so this Retrofit declaration has no caller.
    "lib/api/retrofit/voice_memory_live_audio_api.dart::recoverVault::"
    "VoiceMemoryLiveAudioApi":
        "declaration only — the live path uses HttpCaptureApiClient."
        "postVaultRecovery, which is gated by OfflineVaultRecoveryService",

    # The onboarding brain-dump endpoint. Its client, `BrainDumpUploadService`,
    # has no caller and its screen (`brain_dump_screen.dart`) has been deleted.
    # This is the endpoint the original leak streamed to; the declaration is
    # what is left of it. Kept visible here rather than silently dropped,
    # because the machinery is one call site away from being live again.
    "lib/api/retrofit/voice_memory_onboarding_api.dart::uploadBrainDump::"
    "VoiceMemoryOnboardingApi":
        "declaration only — BrainDumpUploadService has no caller and the "
        "onboarding brain-dump screen was deleted",
}


# --------------------------------------------------------------------------
# What counts as content, and what counts as wire
# --------------------------------------------------------------------------

# Substrings of a parameter or argument name that mean "this is the customer's
# own recording or words", as opposed to metadata travelling beside it.
# `speechLocale`, `durationSeconds` and `captureToken` deliberately do not
# match: they describe a payload, they are not one.
CONTENT_TOKENS = (
    "audio",
    "pcm",
    "transcript",
    "waveform",
    "utterance",
    "dictation",
    "braindump",
    "brain_dump",
    "vault",
    "journaltext",
    "journal_text",
    "entrytext",
    "entry_text",
    "notetext",
    "note_text",
)

# `channel.sink.add(bytes)` — the WebSocket send, and the shape the brain-dump
# pipeline used.
#
# The second alternative matters as much as the first. `LiveAudioSocketConnection`
# exposes `Sink<dynamic> get sink`, so a caller can hold that Sink directly and
# write `_sink.add(chunk)` with no `.sink.` in the line at all — same bytes, same
# socket, one refactor away. Matching only the literal `.sink.add` would leave
# that variant invisible, which is the same shape of blindness as listing five
# boundaries by name. Receivers are matched on the identifier naming a sink, a
# socket or a channel; a plain StreamController like the inbound
# `_serverEventsController.add(event)` does not match and stays quiet.
SINK_SEND = re.compile(
    r"(?:\.\s*sink|\b_?\w*(?:[Ss]ink|[Ss]ocket|[Cc]hannel))"
    r"\s*[?!]*\s*\.\s*add\s*\("
)

# Retrofit write verbs. Read verbs cannot carry a body and are skipped.
RETROFIT_WRITE = re.compile(r"@\s*(?:POST|PUT|PATCH)\s*\(")

# The hand-rolled transport whose write methods are pulled in by name.
TRANSPORT_CLASSES = ("HttpTransport",)
TRANSPORT_WRITE_PREFIXES = ("post", "put", "patch", "upload", "send")

# The authoritative predicate. Its own public methods seed Pass G.
GATE_CLASS = "RemoteProcessingConsentGate"

CLASS_DECL = re.compile(r"\bclass\s+(\w+)\b")

MEMBER_DECL = re.compile(
    r"\b([A-Z]\w*)\s*(?:<[^;={}()]*>)?\s*\??\s+(?:get\s+)?(_?\w+)\s*(?==>|=[^=]|;|\)|,)"
)

CALL_SITE = re.compile(r"(?<![\w$])(_?\w+)\s*\(")

CONTROL_FLOW = {
    "if", "for", "while", "switch", "catch", "return", "assert", "super",
    "this", "await", "yield", "throw", "new", "rethrow", "print",
}


# --------------------------------------------------------------------------
# Lexing helpers (shared shape with tool/check_initstate_provider_writes.py)
# --------------------------------------------------------------------------

def blank_comments_and_strings(source):
    """Replace comment and string contents with spaces, preserving offsets."""
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


def open_bracket(source, close_index):
    """Index of the bracket opening the one that closes at `close_index`."""
    pairs = {")": "(", "]": "[", "}": "{"}
    closer = source[close_index]
    opener = pairs[closer]
    depth = 0
    for i in range(close_index, -1, -1):
        if source[i] == closer:
            depth += 1
        elif source[i] == opener:
            depth -= 1
            if depth == 0:
                return i
    return -1


def class_bodies(source):
    for match in CLASS_DECL.finditer(source):
        brace = source.find("{", match.end())
        if brace < 0:
            continue
        header = source[match.end():brace]
        if ";" in header:  # `class X = A with B;` or a stray match
            continue
        yield match.group(1), header, brace, match_bracket(source, brace)


def member_bodies(source, start, end):
    """Yield (name, params, body_start, body_end) for members of a class body.

    Abstract members and Retrofit stubs have no body; they are yielded with an
    empty span so their signature still registers. Anything nested inside
    another block is skipped, so closures are not mistaken for methods.
    """
    i = start
    while i < end:
        ch = source[i]
        if ch in "{[":
            i = match_bracket(source, i)
            continue
        if ch == "(":
            close = match_bracket(source, i)
            name_match = re.search(r"(\w+)\s*$", source[start:i])
            if name_match is None:
                i = close
                continue
            params = source[i:close]
            tail = re.match(r"\s*(?:async\*?|sync\*)?\s*(\{|=>|;)", source[close:end])
            if tail is None:
                i = close
                continue
            token = tail.group(1)
            body_open = close + tail.end() - 1
            if token == "{":
                body_end = match_bracket(source, body_open)
            elif token == "=>":
                # Keep the arrow inside the body: an expression body *is* a
                # return, and Pass G has to be able to see that.
                body_open = close + tail.end() - 2
                semi = source.find(";", body_open)
                body_end = end if semi < 0 else semi + 1
            else:  # `;` — abstract, external, or a Retrofit declaration.
                body_end = body_open
            yield name_match.group(1), params, body_open, body_end
            i = max(body_end, close)
            continue
        i += 1


def receiver_of(text, call_start):
    """Describe the receiver of the call whose name starts at `call_start`.

    Returns (kind, detail): "none" for a bare call, "name" for an identifier or
    a call result that has to be looked up, "opaque" when it cannot be read.
    """
    prefix = text[:call_start].rstrip()
    prefix = re.sub(r"[?!]$", "", prefix)
    if not prefix.endswith("."):
        return ("none", None)
    prefix = re.sub(r"[?!]?\s*\.$", "", prefix).rstrip()
    if prefix.endswith(")"):
        paren = open_bracket(prefix, len(prefix) - 1)
        if paren < 0:
            return ("opaque", None)
        callee = re.search(r"(\w+)\s*$", prefix[:paren])
        if callee is None:
            return ("opaque", None)
        return ("name", callee.group(1))
    identifier = re.search(r"(\w+)$", prefix)
    if identifier is None:
        return ("opaque", None)
    return ("name", identifier.group(1))


# --------------------------------------------------------------------------
# Structure
# --------------------------------------------------------------------------

class DartClass:
    def __init__(self, path, name, start, end):
        self.path = path
        self.name = name
        self.start = start
        self.end = end
        self.methods = {}   # name -> (params, body, body_offset)
        self.members = {}   # field/getter name -> type name


def collect_classes(files):
    classes = {}
    for path, source in files:
        for name, _header, brace, end in class_bodies(source):
            entry = DartClass(path, name, brace + 1, end)
            for method, params, body_start, body_end in member_bodies(
                source, entry.start, entry.end
            ):
                entry.methods[method] = (
                    params,
                    source[body_start:body_end],
                    body_start,
                )
            body = source[entry.start:entry.end]
            for match in MEMBER_DECL.finditer(body):
                entry.members.setdefault(match.group(2), match.group(1))
            classes.setdefault(name, []).append(entry)
    return classes


def build_member_types(classes):
    member_types = {}
    for entries in classes.values():
        for entry in entries:
            for member, type_name in entry.members.items():
                member_types.setdefault(member, set()).add(type_name)
    return member_types


def owners_of(classes):
    """method name -> set of class names declaring it."""
    owners = {}
    for name, entries in classes.items():
        for entry in entries:
            for method in entry.methods:
                owners.setdefault(method, set()).add(name)
    return owners


def resolve_receiver(entry, classes, member_types, kind, detail):
    """Class names a call receiver may denote. Errs by returning more."""
    if kind == "none":
        return {entry.name}
    if kind != "name" or detail is None:
        return set()
    if detail in classes:            # `TranscriptionService.transcribe(...)`
        return {detail}
    local = entry.members.get(detail)
    if local:
        return {local}
    return set(member_types.get(detail, ()))


def has_content_token(text):
    lowered = text.lower()
    return any(token in lowered for token in CONTENT_TOKENS)


# --------------------------------------------------------------------------
# Pass W — discover the wire primitives
# --------------------------------------------------------------------------

def discover_wire_methods(files, classes):
    """(class, method) pairs that put bytes on the network, found in source."""
    wire = set()

    by_path = {}
    for name, entries in classes.items():
        for entry in entries:
            by_path.setdefault(entry.path, []).append((name, entry))

    for path, source in files:
        local = by_path.get(path, ())
        if not local:
            continue

        # Retrofit: `@POST('/api/...')` immediately above a method declaration.
        for match in RETROFIT_WRITE.finditer(source):
            close = match_bracket(source, source.index("(", match.start()))
            declaration = re.match(
                r"\s*(?:@\w+(?:\s*\([^)]*\))?\s*)*"     # further annotations
                r"(?:[\w<>,\s\?\[\]]+?\s+)?(\w+)\s*\(",  # return type + name
                source[close:],
            )
            if declaration is None:
                continue
            method = declaration.group(1)
            for name, entry in local:
                if method in entry.methods:
                    wire.add((name, method))

        # `<x>.sink.add(...)` — a WebSocket frame going out.
        for match in SINK_SEND.finditer(source):
            for name, entry in local:
                for method, (_p, body, offset) in entry.methods.items():
                    if offset <= match.start() < offset + len(body):
                        wire.add((name, method))

    # The hand-rolled transport's own write methods.
    for transport in TRANSPORT_CLASSES:
        for entry in classes.get(transport, ()):
            for method in entry.methods:
                if method.startswith(TRANSPORT_WRITE_PREFIXES):
                    wire.add((transport, method))

    return wire


# --------------------------------------------------------------------------
# Pass E / Pass G — fixpoints over the call graph
# --------------------------------------------------------------------------

def build_call_index(classes, member_types):
    """One pass over every method body, reused by all three fixpoints.

    Each entry is (caller class, caller method, entry, body, callee, receiver
    classes, offset of the call within the body). Resolving receivers is the
    expensive part and the fixpoints below iterate many times, so it happens
    exactly once.
    """
    index = []
    for name, entries in classes.items():
        for entry in entries:
            for method, (_params, body, _offset) in entry.methods.items():
                for match in CALL_SITE.finditer(body):
                    callee = match.group(1)
                    if callee in CONTROL_FLOW:
                        continue
                    kind, detail = receiver_of(body, match.start())
                    targets = resolve_receiver(
                        entry, classes, member_types, kind, detail
                    )
                    if not targets:
                        continue
                    index.append(
                        (name, method, entry, body, callee, targets, match.start())
                    )
    return index


def grow_over_calls(seed, call_index, on_edge=None):
    """Least fixpoint: a method that calls a member of `seed` joins `seed`."""
    reached = set(seed)
    changed = True
    while changed:
        changed = False
        for name, method, entry, body, callee, targets, at in call_index:
            if (name, method) in reached:
                continue
            if not any((t, callee) in reached for t in targets):
                continue
            if on_edge is not None and not on_edge(entry, method, body, callee, at):
                continue
            reached.add((name, method))
            changed = True
    return reached


def discover_gate_methods(classes, call_index):
    """Pass G — gate consultations, grown over delegation."""
    seed = set()
    for entry in classes.get(GATE_CLASS, ()):
        for method in entry.methods:
            if method.startswith("_") or method == GATE_CLASS:
                continue
            seed.add((GATE_CLASS, method))

    def delegates(entry, method, body, callee, at):
        # A wrapper only counts when its whole job is to answer the question:
        # it must hand the answer back rather than merely touch the gate.
        return "return" in body or "=>" in body or "await" in body

    return grow_over_calls(seed, call_index, on_edge=delegates)


def discover_egress_methods(wire, classes, call_index):
    """Pass E — everything that reaches the wire, restricted to content."""

    def carries_content(entry, method, body, callee, at):
        params = entry.methods[method][0]
        if has_content_token(params):
            return True
        paren = body.find("(", at)
        if paren < 0:
            return False
        return has_content_token(body[paren:match_bracket(body, paren)])

    reachable = grow_over_calls(wire, call_index, on_edge=carries_content)

    content = set()
    for name, method in reachable:
        for entry in classes.get(name, ()):
            if method in entry.methods and has_content_token(
                entry.methods[method][0]
            ):
                content.add((name, method))
    return reachable, content


# --------------------------------------------------------------------------
# Pass C — coverage
# --------------------------------------------------------------------------

def build_callers(call_index, of_interest):
    """class -> set of classes that call one of its methods in `of_interest`."""
    callers = {}
    for name, _method, _entry, _body, callee, targets, _at in call_index:
        for target in targets:
            if target == name or (target, callee) not in of_interest:
                continue
            callers.setdefault(target, set()).add(name)
    return callers


def consulting_classes(call_index, gate_methods):
    """Classes with at least one method that reaches a gate consultation."""
    consulting = {name for name, _method in gate_methods}
    for name, _method, _entry, _body, callee, targets, _at in call_index:
        if any((t, callee) in gate_methods for t in targets):
            consulting.add(name)
    return consulting


def solve_coverage(egress_classes, callers, consulting):
    """Greatest fixpoint: covered until proven otherwise."""
    covered = set(egress_classes)
    changed = True
    while changed:
        changed = False
        for name in list(covered):
            if name in consulting:
                continue
            upstream = callers.get(name, set())
            if not upstream or any(c not in covered for c in upstream):
                covered.discard(name)
                changed = True
    return covered


def uncovered_roots(name, callers, covered, seen=None):
    """Outermost uncovered classes above `name` — the places a fix would go.

    Keyed on rather than the wire site itself, because a wire site is shared:
    `VoiceMemoryCaptureApi.transcribe` is reached both by the gated capture
    pipeline and by an ungated fallback. Allowlisting the *site* would excuse
    every future caller of it; allowlisting the *root* excuses one known one,
    and a new ungated caller shows up as a new root the allowlist has never
    heard of.
    """
    seen = seen or set()
    if name in seen:
        return set()
    seen = seen | {name}
    upstream = {c for c in callers.get(name, set()) if c not in covered}
    if not upstream:
        return {name}
    roots = set()
    for parent in upstream:
        roots |= uncovered_roots(parent, callers, covered, seen)
    return roots or {name}


def uncovered_chain(name, callers, covered, consulting, depth=0, seen=None):
    """Readable trace of why `name` is uncovered, upwards to a root."""
    seen = seen or set()
    if name in seen or depth > 6:
        return []
    seen = seen | {name}
    upstream = sorted(c for c in callers.get(name, set()) if c not in covered)
    if not upstream:
        return [name + "  (no in-tree caller — reachable from any new screen)"]
    lines = []
    for parent in upstream[:3]:
        lines.append(parent)
        lines += ["  " + line
                  for line in uncovered_chain(
                      parent, callers, covered, consulting, depth + 1, seen
                  )]
    return lines


# --------------------------------------------------------------------------
# I/O
# --------------------------------------------------------------------------

_SOURCE_CACHE = {}


def line_of(path, index):
    return _SOURCE_CACHE[path].count("\n", 0, index) + 1


def relative(path):
    return os.path.relpath(path, MOBILE_ROOT)


def dart_sources(root=None):
    """Every Dart file the app compiles, symlinks followed, realpath-deduped."""
    files = []
    for base, dirs, names in os.walk(root or LIB_ROOT, followlinks=True):
        dirs[:] = sorted(dirs)
        for name in sorted(names):
            if not name.endswith(".dart") or name.endswith(".g.dart"):
                continue
            path = os.path.realpath(os.path.join(base, name))
            if path in _SOURCE_CACHE:
                continue
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    raw = handle.read()
            except (OSError, UnicodeDecodeError):
                continue
            _SOURCE_CACHE[path] = raw
            files.append((path, blank_comments_and_strings(raw)))
    return files


# --------------------------------------------------------------------------
# Analysis
# --------------------------------------------------------------------------

def analyse(files):
    classes = collect_classes(files)
    member_types = build_member_types(classes)

    call_index = build_call_index(classes, member_types)

    wire = discover_wire_methods(files, classes)
    gate_methods = discover_gate_methods(classes, call_index)
    reachable, content = discover_egress_methods(wire, classes, call_index)

    callers = build_callers(call_index, reachable)
    consulting = consulting_classes(call_index, gate_methods)
    covered = solve_coverage({n for n, _ in reachable}, callers, consulting)

    # Report at the wire site itself, never at the intermediates above it.
    # Coverage is conjunctive — a class is covered only when *every* caller is
    # — so an uncovered ancestor always leaves the wire site uncovered too, and
    # collapsing to the wire keeps one leak to one finding.
    sites = []
    for name, method in sorted(content & wire):
        for entry in classes.get(name, ()):
            if method not in entry.methods:
                continue
            _params, _body, offset = entry.methods[method]
            sites.append((entry.path, name, method, offset))

    violations = []
    allow_hits = set()
    for path, name, method, offset in sites:
        if name in covered:
            continue
        roots = uncovered_roots(name, callers, covered)
        excused = set()
        for root in roots:
            key = "%s::%s::%s" % (relative(path), method, root)
            for candidate in EGRESS_ALLOWLIST:
                suffix, allowed_method, allowed_root = candidate.split("::")
                if (
                    relative(path).endswith(suffix)
                    and allowed_method == method
                    and allowed_root == root
                ):
                    allow_hits.add(candidate)
                    excused.add(root)
                    break
        remaining = roots - excused
        if not remaining:
            continue
        violations.append((path, name, method, offset, sorted(remaining)))

    return {
        "classes": classes,
        "wire": wire,
        "gate_methods": gate_methods,
        "reachable": reachable,
        "content": content,
        "callers": callers,
        "consulting": consulting,
        "covered": covered,
        "sites": sites,
        "violations": violations,
        "allow_hits": allow_hits,
    }


# --------------------------------------------------------------------------
# Self-test
# --------------------------------------------------------------------------

# Miniatures of every shape this gate has to get right. `LeakySocketClient` and
# the screen above it reconstruct the onboarding brain-dump pipeline: raw PCM
# handed to a WebSocket sink, reached from a first-run screen, with the gate
# named nowhere on the path. The look-alikes are the gated live path, a gated
# upload three facades deep, and non-content traffic.
SELF_TEST_SOURCES = {
    "gate.dart": """
      class RemoteProcessingConsentGate {
        Future<bool> isPurposePermittedNow(RemoteProcessingPurpose p) async {
          return true;
        }
      }

      class ConsentFacade {
        final RemoteProcessingConsentGate _gate = RemoteProcessingConsentGate();
        Future<bool> isPurposeGranted(RemoteProcessingPurpose p) =>
            _gate.isPurposePermittedNow(p);
      }

      class PipelineMiddleware {
        final ConsentFacade _facade = ConsentFacade();
        Future<bool> isPurposeGranted(RemoteProcessingPurpose p) =>
            _facade.isPurposeGranted(p);
      }
    """,
    "transport.dart": """
      class HttpTransport {
        Future<Response> post(String path, {Object? body}) async {
          return _client.post(path);
        }

        Future<Response> postMultipart(String path, {List<Part>? files}) async {
          return _client.send(path);
        }
      }

      class UploadApi {
        @POST('/api/transcribe')
        Future<TranscribeResponseDto> transcribe({
          required File audio,
          required String captureToken,
        });

        @GET('/api/health')
        Future<HealthDto> health();
      }
    """,
    "leak.dart": """
      class LeakySocketClient {
        void sendPcm16kChunk(List<int> pcm16kBytes) {
          _connection!.sink.add(encode(pcm16kBytes));
        }
      }

      class LeakyCoordinator {
        final LeakySocketClient _socket = LeakySocketClient();
        void streamPcm16kChunk(List<int> pcm16kBytes) {
          _socket.sendPcm16kChunk(pcm16kBytes);
        }
      }

      class _BrainDumpScreenState extends State<BrainDumpScreen> {
        final LeakyCoordinator _coordinator = LeakyCoordinator();
        void onAudioChunk(List<int> pcm16kBytes) {
          _coordinator.streamPcm16kChunk(pcm16kBytes);
        }
      }
    """,
    # Same leak, spelled without a `.sink.` anywhere: the Sink is held directly.
    # Beside it, the inbound broadcast controller from the real WebSocket
    # client, which must not be mistaken for an outbound frame.
    "held_sink.dart": """
      class HeldSinkClient {
        final Sink<dynamic> _sink;
        final StreamController<LiveServerEvent> _serverEventsController =
            StreamController<LiveServerEvent>.broadcast();

        void sendPcm16kChunk(List<int> pcm16kBytes) {
          _sink.add(encode(pcm16kBytes));
        }

        void onFrame(LiveServerEvent transcriptEvent) {
          _serverEventsController.add(transcriptEvent);
        }
      }
    """,
    "gated.dart": """
      class GatedSocketClient {
        void sendPcm16kChunk(List<int> pcm16kBytes) {
          _connection!.sink.add(encode(pcm16kBytes));
        }
      }

      class GatedCoordinator {
        final GatedSocketClient _socket = GatedSocketClient();
        final RemoteProcessingConsentGate _gate = RemoteProcessingConsentGate();

        Future<void> streamPcm16kChunk(List<int> pcm16kBytes) async {
          if (!await _gate.isPurposePermittedNow(purpose)) return;
          _socket.sendPcm16kChunk(pcm16kBytes);
        }
      }
    """,
    "deep.dart": """
      class CaptureRepo {
        final UploadApi _api = UploadApi();
        Future<String> postTranscribe({required File audioFile}) {
          return _api.transcribe(audio: audioFile, captureToken: token);
        }
      }

      class TranscribeRunner {
        final CaptureRepo repo = CaptureRepo();
        Future<String> run({required File audioFile}) {
          return repo.postTranscribe(audioFile: audioFile);
        }
      }

      class VoiceHandler {
        final PipelineMiddleware _middleware = PipelineMiddleware();
        final TranscribeRunner runner = TranscribeRunner();

        Future<void> save({required File audioFile}) async {
          if (!await _middleware.isPurposeGranted(purpose)) return;
          await runner.run(audioFile: audioFile);
        }
      }
    """,
    "quiet.dart": """
      class TelemetryUploader {
        final HttpTransport _transport = HttpTransport();
        Future<void> flush(Map<String, Object?> counters) async {
          await _transport.post('/api/metrics', body: counters);
        }
      }

      class AuthClient {
        final HttpTransport _transport = HttpTransport();
        Future<void> sendCode(String email) async {
          await _transport.post('/api/auth/send-code', body: {'email': email});
        }
      }
    """,
}

# Only the reconstructed brain-dump chain may be reported. The gated socket,
# the three-facade-deep upload, and the metadata-only traffic must stay quiet.
SELF_TEST_EXPECTED = {
    ("LeakySocketClient", "sendPcm16kChunk"),
    ("HeldSinkClient", "sendPcm16kChunk"),
}


def self_test(verbose=False):
    files = []
    for name, source in SELF_TEST_SOURCES.items():
        path = os.path.join(MOBILE_ROOT, "tool", "__selftest__", name)
        _SOURCE_CACHE[path] = source
        files.append((path, blank_comments_and_strings(source)))

    result = analyse(files)
    found = {(name, method) for _p, name, method, _o, _r in result["violations"]}
    missing = sorted(SELF_TEST_EXPECTED - found)
    spurious = sorted(found - SELF_TEST_EXPECTED)

    # The passes themselves are pinned too, so a typo in a pattern cannot turn
    # the whole gate into an assertion that nothing matches nothing.
    checks = []
    if ("LeakySocketClient", "sendPcm16kChunk") not in result["wire"]:
        checks.append("sink.add not recognised as a wire primitive")
    if ("HeldSinkClient", "sendPcm16kChunk") not in result["wire"]:
        checks.append("a directly-held Sink.add not recognised as a wire primitive")
    if ("HeldSinkClient", "onFrame") in result["wire"]:
        checks.append("inbound StreamController.add wrongly treated as a send")
    if ("UploadApi", "transcribe") not in result["wire"]:
        checks.append("@POST-annotated method not recognised as a wire primitive")
    if ("UploadApi", "health") in result["wire"]:
        checks.append("@GET wrongly treated as a write")
    if ("HttpTransport", "postMultipart") not in result["wire"]:
        checks.append("HttpTransport write method not discovered")
    if ("ConsentFacade", "isPurposeGranted") not in result["gate_methods"]:
        checks.append("gate delegation not followed one facade deep")
    if ("PipelineMiddleware", "isPurposeGranted") not in result["gate_methods"]:
        checks.append("gate delegation not followed two facades deep")
    if ("CaptureRepo", "postTranscribe") not in result["content"]:
        checks.append("content-carrying repository method not discovered")
    if ("TelemetryUploader", "flush") in result["content"]:
        checks.append("metadata-only upload wrongly classified as content")

    # An allowlist entry has to name the ungated *caller*, not the endpoint,
    # or one excused route would excuse every future one sharing that wire.
    roots = {
        root
        for _p, _n, _m, _o, listed in result["violations"]
        for root in listed
    }
    if roots != {"_BrainDumpScreenState", "HeldSinkClient"}:
        checks.append(
            "violation attributed to %s, expected the outermost ungated "
            "caller _BrainDumpScreenState" % sorted(roots)
        )

    if verbose:
        print("  wire primitives: %s" % sorted(result["wire"]))
        print("  gate methods:    %s" % sorted(result["gate_methods"]))
        print("  content egress:  %s" % sorted(result["content"]))
        print("  covered classes: %s" % sorted(result["covered"]))

    for entry in missing:
        print("self-test MISS: %s" % (entry,))
    for entry in spurious:
        print("self-test FALSE POSITIVE: %s" % (entry,))
    for entry in checks:
        print("self-test BROKEN PASS: %s" % entry)
    if missing or spurious or checks:
        return 1
    print(
        "self-test ok: brain-dump shape (PCM -> sink.add, no gate on the chain) "
        "and the held-Sink variant both flagged; gated socket, three-facade-deep "
        "upload, inbound StreamController and metadata-only traffic stayed quiet"
    )
    return 0


# --------------------------------------------------------------------------
# Entry point
# --------------------------------------------------------------------------

def main():
    # The gate is only as good as its own matching rules, so pin them first.
    if self_test(verbose="--verbose" in sys.argv):
        return 1
    if "--self-test" in sys.argv:
        return 0

    _SOURCE_CACHE.clear()
    files = dart_sources()

    # A scan that reaches nothing reports nothing. `lib/features/` is almost
    # entirely symlinks into `retired_sprawl/`, and a walk that stopped at them
    # would look exactly like a clean bill of health.
    if len(files) < 500:
        print(
            "scan covered only %d Dart files, too few to have walked lib/ — "
            "check that symlinked feature directories are still followed"
            % len(files)
        )
        return 1

    result = analyse(files)

    stale = sorted(set(EGRESS_ALLOWLIST) - result["allow_hits"])
    if stale:
        print("allowlist entries no longer match any egress site:\n")
        for key in stale:
            print("  %s" % key)
        print(
            "\nRemove them. An allowlist that names sites which no longer "
            "exist is not describing this codebase."
        )
        return 1

    if "--inventory" in sys.argv:
        print("wire primitives (%d):" % len(result["wire"]))
        for name, method in sorted(result["wire"]):
            print("  %s.%s" % (name, method))
        print("\ncontent-carrying egress (%d):" % len(result["content"]))
        for name, method in sorted(result["content"]):
            mark = "gated  " if name in result["covered"] else "UNGATED"
            print("  [%s] %s.%s" % (mark, name, method))
        print("\ngate consultations (%d):" % len(result["gate_methods"]))
        for name, method in sorted(result["gate_methods"]):
            print("  %s.%s" % (name, method))

    if not result["violations"]:
        print(
            "every content-carrying egress is reached only through "
            "RemoteProcessingConsentGate\n"
            "  %d dart files, %d wire primitives, %d content-carrying egress "
            "methods,\n  %d gate consultations, %d allowlisted site(s)"
            % (
                len(files),
                len(result["wire"]),
                len(result["content"]),
                len(result["gate_methods"]),
                len(EGRESS_ALLOWLIST),
            )
        )
        return 0

    print("user content can reach the network without consulting the gate:\n")
    for path, name, method, offset, roots in result["violations"]:
        print("  %s:%d  %s.%s" % (relative(path), line_of(path, offset), name, method))
        chain = uncovered_chain(
            name, result["callers"], result["covered"], result["consulting"]
        )
        for line in chain:
            print("      reached from %s" % line)
        for root in roots:
            print(
                "      allowlist key: %s::%s::%s"
                % (relative(path), method, root)
            )
    print(
        "\n%d ungated boundary/boundaries. Route the call through"
        "\nRemoteProcessingConsentGate.isPurposePermittedNow — it is the only"
        "\npredicate that composes per-purpose consent with the \"Never send to"
        "\nserver\" toggle, and it fails closed."
        "\n\nIf a boundary is intentionally reached without the gate, add it to"
        "\nEGRESS_ALLOWLIST in this file with the reason. Silence has to be"
        "\nwritten down." % len(result["violations"])
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())

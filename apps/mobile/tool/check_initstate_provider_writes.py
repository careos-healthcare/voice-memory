#!/usr/bin/env python3
"""Fail when a widget's `initState` can synchronously reach a provider write.

An `async` function body runs synchronously up to its first `await`. A Riverpod
notifier method that assigns `state` before that first suspension therefore
mutates a provider during the widget build phase when it is reached from
`initState`. `ProviderScope` rejects that, but only in debug: `flutter_riverpod`
installs `debugCanModifyProviders` behind `kDebugMode` in `provider_scope.dart`.
Release and profile builds never throw — the kicked-off work is just silently
dropped, sometimes into a `catch` that hides it completely.

A blunt ban on calls inside `initState` would be useless, because most calls
there are fine. The check is two-sided instead:

  Pass A  Collect methods that assign `state` at or before their first `await`.
          Seeds are Riverpod notifier classes. The set then grows over
          same-class delegation (`ensureInitialized() => _initRevenueCat();`)
          and over thin facades that hold a typed notifier field
          (`AuthService.refreshSession() => _notifier.refreshSession();`).

  Pass B  Walk `initState` bodies of `State` / `ConsumerState` classes and
          report calls that reach a Pass A method without being deferred off
          the build phase. A call only counts when it sits at or before the
          first `await` of its enclosing method — the operand of that first
          `await` is still evaluated synchronously, so it counts too.

  Pass C  The same idea one level down, inside a notifier's own `build`.
          Riverpod builds a synchronous notifier's state *from what `build`
          returns*, so `state` cannot be read until `build` has returned —
          `notifier_provider.dart` says so in as many words. A bare
          `state = value` in `build` is legal; a read is not, and
          `state = state.copyWith(...)` is a read. So Pass C runs its own
          Pass A over reads rather than writes, and reports a `build` that
          reaches one of those methods synchronously. Reads reached only
          through a function literal do not count, because the body of a
          callback runs when the callback fires, not when it is installed.

Receivers are resolved coarsely: a `ref.read(...)` / `container.watch(...)`
expression, or an identifier whose declared type can be found anywhere in the
tree. A call is reported only when its receiver resolves to a class that Pass A
proved writes `state` synchronously, which is what keeps `_ticker?.stop()` and
`SomeChangeNotifier.instance.refresh()` out of the report.

"Deferred" means one of the idioms already used in this repo:
`WidgetsBinding.instance.addPostFrameCallback` (`account_screen.dart`),
`Future.microtask` (`paywall_gate.dart`), `Future.delayed`, `scheduleMicrotask`,
`Timer`, or a `.then` continuation.

DIRECTION OF ERROR: this errs toward FALSE NEGATIVES. It follows one kind of
indirection at a time and gives up rather than guessing — callees reached
through a local variable, through a dynamic or inferred (`var`/`final`)
receiver, through a callback, or more than one facade deep are all missed, as
are `state` writes inside a nested closure. That is the intended trade. A guard
that fires on the safe `security_settings_screen.dart` shape, where
`refreshSession` runs after an earlier `await`, would be switched off inside a
week, so silence there matters more than completeness.

Unlike an analyzer-based lint this walks the source directly, so it also sees
the 373 `lib/features` symlinks into `retired_sprawl/` that `analysis_options`
excludes but the app still compiles and ships.
"""

import os
import re
import sys

MOBILE_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB_ROOT = os.path.join(MOBILE_ROOT, "lib")

NOTIFIER_SUPERCLASS = re.compile(r"\b\w*Notifier\b")

# `NotifierProvider<MyNotifier, MyState>` and friends, so a class still
# classifies when its `extends` clause is indirect.
PROVIDER_REGISTRATION = re.compile(r"\b\w*NotifierProvider\s*<\s*(\w+)\s*,")

STATE_WRITE = re.compile(r"(?<![\w.])state\s*(?:\.\s*\w+\s*)?=(?!=)")

# A `state` mention that is not the plain left-hand side of an assignment, so
# `state.copyWith(...)`, `state.isPro`, `state ==` and `f(state)` all count but
# `state = value` does not.
STATE_READ = re.compile(r"(?<![\w.$])state\b(?!\s*=(?!=))")

CLASS_DECL = re.compile(r"\bclass\s+(\w+)\b")

# Widget life-cycles that run inside the build phase. `dispose` is on the list
# in Riverpod's own error text, but it runs during unmount rather than build and
# legitimately tears provider state down, so it is left out here.
BUILD_PHASE_LIFECYCLES = ("initState", "didChangeDependencies", "didUpdateWidget")

STATE_SUPERCLASS = re.compile(r"^\w*State$")

# Fields and getters, used to resolve a call's receiver to a declared type.
MEMBER_DECL = re.compile(
    r"\b([A-Z]\w*)\s*(?:<[^;={}()]*>)?\s*\??\s+(?:get\s+)?(_?\w+)\s*(?==>|=[^=]|;|\)|,)"
)

# Call sites that hand work to a later frame, microtask, or event. The
# `Future<void>.microtask(...)` spelling carries a type argument, and
# `ref.onDispose` / `ref.listenSelf` / `stream.listen` all install a callback
# rather than running one.
DEFERRALS = re.compile(
    r"(?:addPostFrameCallback|scheduleMicrotask|Timer\s*\.\s*run"
    r"|Future\s*(?:<[^<>()]*>)?\s*\.\s*(?:microtask|delayed|sync)"
    r"|(?<![\w.])Future\s*(?:<[^<>()]*>)?\s*\("
    r"|(?<![\w.])Timer\s*\("
    r"|onDispose|listenSelf|listenManual|\.\s*listen"
    r"|\.\s*then)\s*\("
)

# `() {`, `(x) {`, `(Foo a) async {`, `() =>` — a function literal. Its body
# runs when the callback fires, not at the site that installs it.
CLOSURE_START = re.compile(
    r"\(\s*(?:[\w<>,?\s\[\]]*)\)\s*(?:async\s*\*?\s*|sync\s*\*\s*)?(\{|=>)"
)

CALL_SITE = re.compile(r"(?<![\w$])(_?\w+)\s*\(")

READER_CALLS = {"read", "watch", "listen", "refresh"}

CONTROL_FLOW = {
    "if", "for", "while", "switch", "catch", "return", "assert", "super",
    "this", "await", "yield", "throw", "new", "rethrow",
}


# --------------------------------------------------------------------------
# Lexing helpers
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


# --------------------------------------------------------------------------
# Structure
# --------------------------------------------------------------------------

class DartClass:
    def __init__(self, path, name, header, start, end):
        self.path = path
        self.name = name
        self.header = header
        self.start = start
        self.end = end
        self.methods = {}   # name -> (body, offset)
        self.members = {}   # field/getter name -> type name


def class_bodies(source):
    for match in CLASS_DECL.finditer(source):
        brace = source.find("{", match.end())
        if brace < 0:
            continue
        header = source[match.end():brace]
        if ";" in header:  # `class X = A with B;` or a stray match
            continue
        yield match.group(1), header, brace, match_bracket(source, brace)


def method_bodies(source, start, end):
    """Yield (name, body_start, body_end) for methods declared in a class body.

    Anything nested inside another block is skipped, so local functions and
    closures are not mistaken for methods.
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
            tail = re.match(r"\s*(?:async\*?|sync\*)?\s*(\{|=>)", source[close:end])
            if name_match and tail:
                body_open = close + tail.end() - 1
                if tail.group(1) == "{":
                    body_end = match_bracket(source, body_open)
                else:
                    semi = source.find(";", body_open)
                    body_end = end if semi < 0 else semi + 1
                yield name_match.group(1), body_open, body_end
                i = body_end
                continue
            i = close
            continue
        i += 1


def first_await_statement_end(body):
    """End offset of the statement holding the first top-level `await`.

    The operand of an `await` is evaluated *before* the suspension, so the
    whole first-await statement is still synchronous. Everything after it is
    already off the build phase.
    """
    depth = 0
    await_at = None
    for match in re.finditer(r"[{}()\[\]]|(?<![\w.])await(?![\w])|;", body):
        token = match.group(0)
        if token in "{([":
            depth += 1
        elif token in "})]":
            depth -= 1
        elif token == "await" and await_at is None:
            await_at = match.start()
        elif token == ";" and await_at is not None and depth <= 1:
            return match.end()
    return None if await_at is None else len(body)


def deferred_spans(text):
    spans = []
    for match in DEFERRALS.finditer(text):
        paren = text.index("(", match.end() - 1)
        spans.append((match.start(), match_bracket(text, paren)))
    return spans


def closure_spans(text):
    """Spans covering function-literal bodies inside `text`."""
    spans = []
    for match in CLOSURE_START.finditer(text):
        if match.group(1) == "{":
            brace = text.index("{", match.end() - 1)
            spans.append((match.start(), match_bracket(text, brace)))
            continue
        end = len(text)
        depth = 0
        for i in range(match.end(), len(text)):
            if text[i] in "([{":
                depth += 1
            elif text[i] in ")]}":
                if depth == 0:
                    end = i
                    break
                depth -= 1
            elif text[i] in ";," and depth == 0:
                end = i
                break
        spans.append((match.start(), end))
    return spans


def receiver_of(text, call_start):
    """Describe the receiver of the call whose name starts at `call_start`.

    Returns (kind, detail) where kind is one of "none" (bare call), "reader"
    (a `ref.read(...)`-style expression), "name" (an identifier whose type has
    to be looked up), or "opaque".
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
        if callee.group(1) in READER_CALLS:
            return ("reader", callee.group(1))
        return ("name", callee.group(1))
    identifier = re.search(r"(\w+)$", prefix)
    if identifier is None:
        return ("opaque", None)
    return ("name", identifier.group(1))


# --------------------------------------------------------------------------
# Passes
# --------------------------------------------------------------------------

def collect_classes(files):
    classes = {}
    registered = set()
    for _, source in files:
        for match in PROVIDER_REGISTRATION.finditer(source):
            registered.add(match.group(1))

    for path, source in files:
        for name, header, brace, end in class_bodies(source):
            entry = DartClass(path, name, header, brace + 1, end)
            for method, body_start, body_end in method_bodies(
                source, entry.start, entry.end
            ):
                entry.methods[method] = (source[body_start:body_end], body_start)
            body = source[entry.start:entry.end]
            for match in MEMBER_DECL.finditer(body):
                entry.members.setdefault(match.group(2), match.group(1))
            classes.setdefault(name, []).append(entry)
    return classes, registered


def is_notifier(entry, registered):
    if entry.name in registered:
        return True
    extends = re.search(r"\bextends\s+([\w$]+)", entry.header)
    return extends is not None and bool(NOTIFIER_SUPERCLASS.search(extends.group(1)))


def collect_sync_writers(classes, registered, member_types,
                         hazard=STATE_WRITE, verb="writes",
                         skip_closures=False):
    """Pass A — methods that touch `state` at or before their first await."""
    writers = {}        # method name -> {evidence label}
    owners = {}         # class name -> {method name}

    def note(entry, method, label):
        writers.setdefault(method, set()).add(label)
        owners.setdefault(entry.name, set()).add(method)

    notifiers = [
        entry
        for entries in classes.values()
        for entry in entries
        if is_notifier(entry, registered)
    ]

    for entry in notifiers:
        for method, (body, offset) in entry.methods.items():
            if method == "build":
                # `build` is the caller Pass C looks at, never a callee.
                continue
            limit = first_await_statement_end(body)
            region = body if limit is None else body[:limit]
            hit = hazard.search(region)
            if hit:
                note(entry, method, "%s.%s %s state at %s" % (
                    entry.name, method, verb,
                    location(entry.path, offset + hit.start())
                ))

    # Grow the set over same-class delegation and over typed facade fields,
    # e.g. `AuthService.refreshSession() => _notifier.refreshSession();`.
    changed = True
    while changed:
        changed = False
        for entries in classes.values():
            for entry in entries:
                for method, (body, offset) in entry.methods.items():
                    if method == "build":
                        continue
                    if method in owners.get(entry.name, ()):
                        continue
                    reached = delegates_to_writer(
                        entry, body, writers, owners, member_types,
                        skip_closures=skip_closures,
                    )
                    if reached is None:
                        continue
                    note(entry, method, "%s.%s delegates to %s at %s" % (
                        entry.name, method, reached,
                        location(entry.path, offset),
                    ))
                    changed = True
    return writers, owners


def delegates_to_writer(entry, body, writers, owners, member_types,
                        skip_closures=False):
    limit = first_await_statement_end(body)
    limit = len(body) if limit is None else limit
    region = body[:limit]
    spans = deferred_spans(region)
    if skip_closures:
        spans += closure_spans(region)
    for match in CALL_SITE.finditer(region):
        if any(start <= match.start() < end for start, end in spans):
            continue
        callee = match.group(1)
        if callee in CONTROL_FLOW or callee not in writers:
            continue
        kind, detail = receiver_of(region, match.start())
        if kind == "none":
            if callee in entry.methods and callee in owners.get(entry.name, ()):
                return "%s.%s" % (entry.name, callee)
            continue
        if kind == "reader":
            return callee
        if kind == "name":
            for owner in resolve_types(entry, detail, member_types):
                if callee in owners.get(owner, ()):
                    return "%s.%s" % (owner, callee)
    return None


def resolve_types(entry, identifier, member_types):
    """Declared types for `identifier`, preferring the enclosing class."""
    local = entry.members.get(identifier) if entry is not None else None
    if local:
        return [local]
    return sorted(member_types.get(identifier, ()))


def find_build_violations(classes, registered, readers, owners, member_types):
    """Pass C — a notifier's own `build` reaching a method that reads `state`.

    Only direct calls out of `build` are considered. Following them further
    would mean re-deciding, at every hop, whether the callee still runs during
    `build`, and the delegation growth in Pass A already carries that reach
    into the reader set.
    """
    violations = []
    for entries in classes.values():
        for entry in entries:
            if not is_notifier(entry, registered):
                continue
            if "build" not in entry.methods:
                continue
            body, offset = entry.methods["build"]
            limit = first_await_statement_end(body)
            region = body if limit is None else body[:limit]
            spans = deferred_spans(region) + closure_spans(region)
            for match in CALL_SITE.finditer(region):
                if any(start <= match.start() < end for start, end in spans):
                    continue
                callee = match.group(1)
                if callee in CONTROL_FLOW or callee not in readers:
                    continue
                kind, detail = receiver_of(region, match.start())
                via = None
                if kind == "none" and callee in owners.get(entry.name, ()):
                    via = entry.name
                elif kind == "reader":
                    via = detail
                elif kind == "name":
                    for owner in resolve_types(entry, detail, member_types):
                        if callee in owners.get(owner, ()):
                            via = owner
                            break
                if via is None:
                    continue
                violations.append((
                    relative(entry.path),
                    line_of(entry.path, offset + match.start()),
                    entry.name,
                    "build",
                    callee,
                    via,
                    tuple(sorted(readers[callee])),
                ))
    return violations


def find_violations(classes, registered, writers, owners, member_types):
    """Pass B — initState bodies that reach a Pass A method synchronously."""
    violations = []
    for entries in classes.values():
        for entry in entries:
            extends = re.search(r"\bextends\s+([\w$]+)", entry.header)
            if extends is None or not STATE_SUPERCLASS.match(extends.group(1)):
                continue
            lifecycles = [
                name for name in BUILD_PHASE_LIFECYCLES if name in entry.methods
            ]
            if not lifecycles:
                continue

            def walk(body, offset, seen):
                found = []
                limit = first_await_statement_end(body)
                limit = len(body) if limit is None else limit
                region = body[:limit]
                spans = deferred_spans(region)
                for match in CALL_SITE.finditer(region):
                    if any(s <= match.start() < e for s, e in spans):
                        continue
                    callee = match.group(1)
                    if callee in CONTROL_FLOW:
                        continue
                    kind, detail = receiver_of(region, match.start())
                    if callee in entry.methods and kind == "none" and callee not in seen:
                        inner_body, inner_offset = entry.methods[callee]
                        found += walk(inner_body, inner_offset, seen | {callee})
                        continue
                    if callee not in writers:
                        continue
                    if kind == "reader":
                        found.append((offset + match.start(), callee, detail))
                    elif kind == "name":
                        for owner in resolve_types(entry, detail, member_types):
                            if callee in owners.get(owner, ()):
                                found.append((offset + match.start(), callee, owner))
                                break
                return found

            for lifecycle in lifecycles:
                body, offset = entry.methods[lifecycle]
                for at, callee, via in walk(body, offset, {lifecycle}):
                    violations.append(
                        (
                            relative(entry.path),
                            line_of(entry.path, at),
                            entry.name,
                            lifecycle,
                            callee,
                            via,
                            tuple(sorted(writers[callee])),
                        )
                    )
    return violations


# --------------------------------------------------------------------------
# I/O
# --------------------------------------------------------------------------

_SOURCE_CACHE = {}


def line_of(path, index):
    return _SOURCE_CACHE[path].count("\n", 0, index) + 1


def relative(path):
    return os.path.relpath(path, MOBILE_ROOT)


def location(path, index):
    return "%s:%d" % (relative(path), line_of(path, index))


def dart_sources():
    files = []
    for root, dirs, names in os.walk(LIB_ROOT, followlinks=True):
        dirs[:] = sorted(dirs)
        for name in sorted(names):
            if not name.endswith(".dart") or name.endswith(".g.dart"):
                continue
            path = os.path.realpath(os.path.join(root, name))
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
# Self-test
# --------------------------------------------------------------------------

# Miniature versions of every shape this gate has to get right. The first six
# are the real defects it was written for; the last two are the look-alikes it
# must stay quiet about, both of which reach the notifier only after an earlier
# `await` has already taken them off the build phase.
SELF_TEST_SOURCES = {
    "notifiers.dart": """
      final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
        FeedNotifier.new,
      );

      class FeedNotifier extends Notifier<FeedState> {
        @override
        FeedState build() => const FeedState();

        Future<void> refresh() async {
          state = state.copyWith(loading: true);
          await repository.fetch();
          state = state.copyWith(loading: false);
        }
      }

      class BillingNotifier extends Notifier<BillingState> {
        @override
        BillingState build() => const BillingState();

        Future<void> ensureInitialized() => _init();

        Future<void> _init() async {
          state = state.copyWith(loading: true);
          await service.start();
        }
      }

      class SafeNotifier extends Notifier<SafeState> {
        @override
        SafeState build() => const SafeState();

        Future<void> load() async {
          final value = await repository.fetch();
          state = state.copyWith(value: value);
        }
      }

      class BillingFacade {
        final BillingNotifier _notifier;
        Future<void> ensureInitialized() => _notifier.ensureInitialized();
      }

      class Ticker {
        void stop() {}
      }
    """,
    # Pass C. `SubscriptionNotifier` is the shape that motivated it; the three
    # below it are the notifier builds that must stay quiet — a deferred
    # kickoff, a bare write with no read, and a method that installs a callback
    # which reads `state` only once it fires.
    "notifier_builds.dart": """
      class SubscriptionNotifier extends Notifier<SubscriptionState> {
        @override
        SubscriptionState build() {
          unawaited(_initRevenueCat());
          return const SubscriptionState();
        }

        Future<void> _initRevenueCat() async {
          state = state.copyWith(loading: true);
          await service.initialize();
        }
      }

      class DeferredBootstrapNotifier extends Notifier<BootstrapState> {
        @override
        BootstrapState build() {
          unawaited(Future<void>.microtask(_initBilling));
          ref.onDispose(() => _initBilling());
          return const BootstrapState();
        }

        Future<void> _initBilling() async {
          state = state.copyWith(loading: true);
          await service.initialize();
        }
      }

      class SeedingNotifier extends Notifier<SeedState> {
        @override
        SeedState build() {
          _seed();
          return const SeedState();
        }

        void _seed() {
          state = const SeedState.empty();
        }
      }

      class TelemetryNotifier extends Notifier<TelemetryState> {
        @override
        TelemetryState build() {
          _bindTelemetry();
          return const TelemetryState();
        }

        void _bindTelemetry() {
          _subscription = _stream.listen(_onSnapshot);
          _listener = () {
            _onSnapshot(_service.diagnostics);
          };
          _service.addListener(_listener);
        }

        void _onSnapshot(Snapshot snapshot) {
          state = state.copyWith(snapshot: snapshot);
        }
      }
    """,
    "widgets.dart": """
      class _DirectState extends State<Direct> {
        @override
        void initState() {
          super.initState();
          unawaited(ref.read(feedProvider.notifier).refresh());
        }
      }

      class _IndirectState extends State<Indirect> {
        FeedNotifier get _feed => container.read(feedProvider.notifier);

        @override
        void initState() {
          super.initState();
          unawaited(_load());
        }

        Future<void> _load() async {
          await _feed.refresh();
        }
      }

      class _FacadeState extends State<Facade> {
        final BillingFacade billing = BillingFacade();

        @override
        void initState() {
          super.initState();
          unawaited(_load());
        }

        Future<void> _load() async {
          await billing.ensureInitialized();
        }
      }

      class _LifecycleState extends State<Lifecycle> {
        final BillingFacade billing = BillingFacade();

        @override
        void didUpdateWidget(covariant Lifecycle oldWidget) {
          super.didUpdateWidget(oldWidget);
          unawaited(billing.ensureInitialized());
        }
      }

      class _DeferredState extends State<Deferred> {
        @override
        void initState() {
          super.initState();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            unawaited(ref.read(feedProvider.notifier).refresh());
          });
        }
      }

      class _MicrotaskState extends State<Microtask> {
        @override
        void initState() {
          super.initState();
          unawaited(
            Future.microtask(() => ref.read(feedProvider.notifier).refresh()),
          );
        }
      }

      class _AfterAwaitState extends State<AfterAwait> {
        final Lock _appLock = Lock();
        final BillingFacade billing = BillingFacade();

        @override
        void initState() {
          super.initState();
          unawaited(_refresh());
        }

        Future<void> _refresh() async {
          final enabled = await _appLock.isEnabled();
          await billing.ensureInitialized();
        }
      }

      class _TickerState extends State<TickerHost> {
        Ticker? _ticker;

        @override
        void initState() {
          super.initState();
          _ticker?.stop();
        }
      }
    """,
}

SELF_TEST_EXPECTED = {
    ("widgets.dart", "_DirectState", "initState"),
    ("widgets.dart", "_IndirectState", "initState"),
    ("widgets.dart", "_FacadeState", "initState"),
    ("widgets.dart", "_LifecycleState", "didUpdateWidget"),
}

SELF_TEST_EXPECTED_BUILDS = {
    ("notifier_builds.dart", "SubscriptionNotifier", "build"),
}


def self_test():
    files = []
    for name, source in SELF_TEST_SOURCES.items():
        path = os.path.join(MOBILE_ROOT, "tool", "__selftest__", name)
        _SOURCE_CACHE[path] = source
        files.append((path, blank_comments_and_strings(source)))

    classes, registered = collect_classes(files)
    member_types = {}
    for entries in classes.values():
        for entry in entries:
            for member, type_name in entry.members.items():
                member_types.setdefault(member, set()).add(type_name)
    writers, owners = collect_sync_writers(classes, registered, member_types)
    violations = find_violations(classes, registered, writers, owners, member_types)
    readers, reader_owners = collect_sync_writers(
        classes, registered, member_types,
        hazard=STATE_READ, verb="reads", skip_closures=True,
    )
    build_violations = find_build_violations(
        classes, registered, readers, reader_owners, member_types
    )

    found = {
        (os.path.basename(path), class_name, lifecycle)
        for path, _, class_name, lifecycle, _, _, _ in violations
    }
    found_builds = {
        (os.path.basename(path), class_name, lifecycle)
        for path, _, class_name, lifecycle, _, _, _ in build_violations
    }
    missing = sorted(SELF_TEST_EXPECTED - found)
    spurious = sorted(found - SELF_TEST_EXPECTED)
    missing += sorted(SELF_TEST_EXPECTED_BUILDS - found_builds)
    spurious += sorted(found_builds - SELF_TEST_EXPECTED_BUILDS)

    for name in ("refresh", "ensureInitialized"):
        if name not in writers:
            missing.append(("<pass A>", name, "not detected as a sync writer"))
    if "load" in writers:
        spurious.append(("<pass A>", "load", "writes state only after an await"))
    if "_initRevenueCat" not in readers:
        missing.append(("<pass C>", "_initRevenueCat", "not detected as a sync reader"))
    if "_seed" in readers:
        spurious.append(("<pass C>", "_seed", "assigns state without reading it"))
    if "_bindTelemetry" in readers:
        spurious.append(
            ("<pass C>", "_bindTelemetry", "reaches a reader only via a callback")
        )

    for entry in missing:
        print("self-test MISS: %s" % (entry,))
    for entry in spurious:
        print("self-test FALSE POSITIVE: %s" % (entry,))
    if missing or spurious:
        return 1
    print(
        "self-test ok: %d life-cycle and %d notifier-build shapes flagged, "
        "deferred/post-await/callback/non-provider look-alikes stayed quiet"
        % (len(found), len(found_builds))
    )
    return 0


def main():
    # The gate is only as good as its own matching rules, so pin them first.
    if self_test():
        return 1
    if "--self-test" in sys.argv:
        return 0

    files = dart_sources()
    classes, registered = collect_classes(files)

    member_types = {}
    for entries in classes.values():
        for entry in entries:
            for member, type_name in entry.members.items():
                member_types.setdefault(member, set()).add(type_name)

    writers, owners = collect_sync_writers(classes, registered, member_types)
    violations = find_violations(classes, registered, writers, owners, member_types)

    readers, reader_owners = collect_sync_writers(
        classes, registered, member_types,
        hazard=STATE_READ, verb="reads", skip_closures=True,
    )
    build_violations = find_build_violations(
        classes, registered, readers, reader_owners, member_types
    )

    if "--list-writers" in sys.argv:
        for name in sorted(writers):
            print("%s: %s" % (name, "; ".join(sorted(writers[name]))))

    if not violations and not build_violations:
        print(
            "no build-phase life-cycle reaches a synchronous provider write, "
            "and no notifier build reads its own state "
            "(%d dart files, %d sync-writing methods across %d classes, "
            "%d sync-reading methods across %d classes)"
            % (len(files), len(writers), len(owners),
               len(readers), len(reader_owners))
        )
        return 0

    def report(entries):
        for path, line, class_name, lifecycle, callee, via, labels in sorted(
            set(entries)
        ):
            print("  %s:%d  %s.%s -> %s() via %s" % (
                path, line, class_name, lifecycle, callee, via
            ))
            for label in labels:
                print("      %s" % label)

    if violations:
        print("a build-phase life-cycle reaches a synchronous provider write:\n")
        report(violations)
        print(
            "\n%d violation(s). An async body runs synchronously up to its first"
            "\nawait, so this mutates a provider during build. ProviderScope only"
            "\ninstalls that check in debug, so a release build silently skips the"
            "\nwork instead of failing."
            "\n\nFix: defer the kickoff, as in lib/screens/account_screen.dart:"
            "\n  WidgetsBinding.instance.addPostFrameCallback((_) {"
            "\n    if (!mounted) return;"
            "\n    unawaited(_yourAsyncMethod());"
            "\n  });" % len(violations)
        )

    if build_violations:
        if violations:
            print("")
        print("a notifier's build() reaches a method that reads its state:\n")
        report(build_violations)
        print(
            "\n%d violation(s). A synchronous notifier has no state until build()"
            "\nreturns, so reading it from work build() kicks off throws"
            "\n'Tried to read the state of an uninitialized provider' — and"
            "\n`state = state.copyWith(...)` is a read."
            "\n\nFix: defer the kickoff by a microtask and expose the future, as"
            "\nin lib/providers/subscription_provider.dart:"
            "\n  _bootstrap = Future<void>.microtask(ensureInitialized);"
            "\n  unawaited(_bootstrap);" % len(build_violations)
        )
    return 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:io';

/// Cross-references capability flags, flag-gated UI, and the V1 route
/// allowlist / quarantine lists.
///
/// Existing audits each see one slice:
/// - [audit_v1_permissions.sh] greps `name = true/false` literals only
/// - [validate_v1_production_graph.sh] extracts `*Screen` names vs an allowlist
/// - [ProductionRouteLinkGate] scans quoted `push('/path')` in a few screens
///   and does not read [V1CapabilityRegistry] or `RouteCatalog` identifiers
///
/// Grounded in two real misses:
/// 1. Pattern exploration — getter → `bool.fromEnvironment`, widgets
///    `push(RouteCatalog.explorePatterns)`, `/explore` quarantined.
/// 2. Trend pattern summary — same flag shape, inline card (no route).
///
/// Run from apps/mobile:
///   dart run tool/audit_v1_reachability.dart
///   bash tool/audit_v1_reachability.sh
void main() {
  final root = _findMobileRoot();
  final engine = ReachabilityAudit(root);
  final code = engine.run();
  exit(code);
}

String _findMobileRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File('${dir.path}/pubspec.yaml');
    final tool = Directory('${dir.path}/tool');
    if (pubspec.existsSync() && tool.existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'Could not find apps/mobile (pubspec.yaml + tool/) from '
        '${Directory.current.path}',
      );
    }
    dir = parent;
  }
}

class ReachabilityAudit {
  ReachabilityAudit(this.root);

  final String root;
  final _failures = <String>[];

  int run() {
    final registryFile = File(
      '$root/lib/core/config/v1_capability_registry.dart',
    );
    final catalogFile = File('$root/lib/router/route_catalog.dart');
    final routesFile = File('$root/lib/router/v1_route_registry.dart');
    for (final file in [registryFile, catalogFile, routesFile]) {
      if (!file.existsSync()) {
        stderr.writeln('error: missing ${file.path}');
        return 1;
      }
    }

    final catalog = _parseStringConsts(catalogFile.readAsStringSync());
    final tables = _parseRouteTables(routesFile.readAsStringSync(), catalog);
    final flags = _parseCapabilityFlags(registryFile.readAsStringSync());
    if (flags.isEmpty) {
      stderr.writeln(
        'error: walked 0 capability flags in v1_capability_registry.dart — '
        'parser saw nothing, so the audit compared against nothing',
      );
      return 1;
    }

    print('==> capability flag inventory (${flags.length})');
    for (final flag in flags) {
      _resolveFlag(flag);
      print('    ${_formatFlag(flag)}');
    }

    print('==> flag-gated navigations vs V1 allowlist / quarantine');
    var checked = 0;
    for (final flag in flags) {
      final sites = _libFilesReferencing(flag.name);
      for (final site in sites) {
        final routes = _flagGatedNavigationsIn(
          File(site).readAsLinesSync(),
          flag.name,
          catalog,
        );
        if (routes.isEmpty) continue;
        checked += 1;
        for (final route in routes) {
          _checkJoin(flag: flag, site: site, route: route, tables: tables);
        }
      }
    }
    if (checked == 0) {
      print('    no flag-gated push/go sites found');
    }

    if (_failures.isEmpty) {
      print('OK — capability flags, gated CTAs, and route lists agree');
      return 0;
    }

    print('FAIL — ${_failures.length} reachability mismatch(es)');
    for (final failure in _failures) {
      stderr.writeln('error: $failure');
    }
    return 1;
  }

  void _checkJoin({
    required _Flag flag,
    required String site,
    required String route,
    required _RouteTables tables,
  }) {
    final rel = site.startsWith('$root/')
        ? site.substring(root.length + 1)
        : site;
    final quarantined = tables.quarantined.contains(route);
    final allowlisted = tables.isAllowlisted(route);

    // Literal `false` cannot turn on without a code change (tree-shaken).
    // fromEnvironment defaults can turn on via dart-define — tonight's case.
    if (!flag.canEnableWithoutCodeChange) return;

    if (quarantined || !allowlisted) {
      final define = flag.dartDefine == null
          ? 'it is compile-time true'
          : 'it can be enabled via --dart-define=${flag.dartDefine}=true';
      final where = <String>[
        if (quarantined) 'listed in V1RouteRegistry.quarantinedExactPaths',
        if (!allowlisted)
          'absent from V1RouteRegistry allowlist (supporting/primary/paid/prefix)',
      ].join(' and ');
      _failures.add(
        '${flag.name} — $define, but $rel navigates to $route, which is $where. '
        'The widget can appear while V1NavigationGuard still redirects the route.',
      );
    } else {
      print('    OK  ${flag.name} → $route  ($rel)');
    }
  }

  List<_Flag> _parseCapabilityFlags(String source) {
    final flags = <_Flag>[];
    final literal = RegExp(
      r'static const bool (\w+)\s*=\s*(true|false)\s*;',
    );
    for (final match in literal.allMatches(source)) {
      flags.add(
        _Flag(
          name: match[1]!,
          kind: 'literal',
          literalValue: match[2] == 'true',
        ),
      );
    }

    final getter = RegExp(
      r'static bool get (\w+)\s*=>\s*([^;]+);',
      multiLine: true,
    );
    for (final match in getter.allMatches(source)) {
      final name = match[1]!;
      if (name == 'launchCapabilityIds') continue;
      flags.add(
        _Flag(
          name: name,
          kind: 'getter',
          getterExpr: match[2]!.replaceAll(RegExp(r'\s+'), ' ').trim(),
        ),
      );
    }
    return flags;
  }

  void _resolveFlag(_Flag flag) {
    if (flag.kind == 'literal') {
      flag.canEnableWithoutCodeChange = flag.literalValue == true;
      flag.resolved = flag.literalValue == true ? 'const true' : 'const false';
      return;
    }

    final expr = flag.getterExpr ?? '';
    final member = RegExp(r'^(\w+)\.(\w+)$').firstMatch(expr);
    if (member == null) {
      flag.resolved = 'unresolved getter ($expr)';
      _failures.add(
        '${flag.name} getter `$expr` is not `Class.member` — cannot follow '
        'to bool.fromEnvironment or a literal',
      );
      return;
    }

    final className = member[1]!;
    final file = _findClassFile(className);
    if (file == null) {
      flag.resolved = 'missing class $className';
      _failures.add(
        '${flag.name} follows $className.${member[2]} but no class $className '
        'was found under lib/',
      );
      return;
    }

    final env = _followFromEnvironment(file.readAsStringSync(), member[2]!);
    if (env == null) {
      flag.resolved =
          'followed $className.${member[2]} in '
          '${_rel(file.path)} — not fromEnvironment / literal';
      _failures.add(
        '${flag.name} follows $className.${member[2]} in ${_rel(file.path)} '
        'but that member is not bool.fromEnvironment or a bool literal',
      );
      return;
    }

    flag.dartDefine = env.name;
    flag.fromEnvironmentDefault = env.defaultValue;
    // dart-define can flip a default-false compile-time flag.
    flag.canEnableWithoutCodeChange = true;
    flag.resolved =
        'bool.fromEnvironment(${env.name}, defaultValue: ${env.defaultValue}) '
        'via $className.${member[2]}';
  }

  _EnvKey? _followFromEnvironment(
    String source,
    String member, {
    int depth = 0,
  }) {
    if (depth > 6) return null;

    final fromEnv = RegExp(
      "static const bool $member\\s*=\\s*bool\\.fromEnvironment\\(\\s*'([^']+)'"
      '(?:\\s*,\\s*defaultValue:\\s*(true|false))?',
    ).firstMatch(source);
    if (fromEnv != null) {
      return _EnvKey(fromEnv[1]!, fromEnv[2] == 'true');
    }

    final literal = RegExp(
      'static const bool $member\\s*=\\s*(true|false)\\s*;',
    ).firstMatch(source);
    if (literal != null) {
      return null;
    }

    final getter = RegExp(
      'static bool get $member\\s*=>\\s*([^;]+);',
      multiLine: true,
    ).firstMatch(source);
    if (getter == null) return null;

    var expr = getter[1]!.replaceAll(RegExp(r'\s+'), ' ').trim();
    expr = expr.replaceFirst(RegExp(r'^debugOverride \?\? '), '');

    final nestedEnv = RegExp(
      "bool\\.fromEnvironment\\(\\s*'([^']+)'(?:\\s*,\\s*defaultValue:\\s*(true|false))?",
    ).firstMatch(expr);
    if (nestedEnv != null) {
      return _EnvKey(nestedEnv[1]!, nestedEnv[2] == 'true');
    }

    final ident = RegExp(r'^(\w+)$').firstMatch(expr);
    if (ident != null) {
      return _followFromEnvironment(source, ident[1]!, depth: depth + 1);
    }
    return null;
  }

  File? _findClassFile(String className) {
    final hits = <File>[];
    _walkLib((file) {
      if (file.path.endsWith('.g.dart')) return;
      final text = file.readAsStringSync();
      if (RegExp('class $className\\b').hasMatch(text)) {
        hits.add(file);
      }
    });
    if (hits.isEmpty) return null;
    hits.sort((a, b) => a.path.length.compareTo(b.path.length));
    return hits.first;
  }

  List<String> _libFilesReferencing(String flagName) {
    final needle = 'V1CapabilityRegistry.$flagName';
    final files = <String>[];
    _walkLib((file) {
      if (file.path.endsWith('v1_capability_registry.dart')) return;
      if (file.path.endsWith('.g.dart')) return;
      if (file.readAsStringSync().contains(needle)) {
        files.add(file.path);
      }
    });
    files.sort();
    return files;
  }

  /// Two real gating shapes, from tonight's widgets:
  /// - Early return: `if (!V1CapabilityRegistry.x) return SizedBox.shrink()`
  ///   then a later `push` in the same file (entry card, save-receipt CTA).
  /// - Wrap: `if (V1CapabilityRegistry.x) ListTile(onTap: () => push(...))`.
  ///
  /// A bare mention (`showOnDeviceLink: V1CapabilityRegistry.x`) is not a
  /// navigation guard and must not steal every later Settings `push`.
  Set<String> _flagGatedNavigationsIn(
    List<String> lines,
    String flagName,
    Map<String, String> catalog,
  ) {
    final routes = <String>{};
    final needle = 'V1CapabilityRegistry.$flagName';
    final earlyReturn = _hasEarlyReturnGuard(lines, needle);
    final wrapRanges = _wrapIfRanges(lines, needle);
    final call = RegExp(
      r'''(?:context\.)?(?:push|go|pushReplacement)\(\s*(?:RouteCatalog\.(\w+)|'(/[^']+)'|"(/[^"]+)")''',
    );
    for (var i = 0; i < lines.length; i++) {
      final span = [
        _stripLineComment(lines[i]),
        if (i + 1 < lines.length) _stripLineComment(lines[i + 1]),
      ].join(' ');
      final match = call.firstMatch(span);
      if (match == null) continue;
      final wrapped = wrapRanges.any((r) => i >= r.$1 && i <= r.$2);
      if (!earlyReturn && !wrapped) continue;
      final ident = match[1];
      final quoted = match[2] ?? match[3];
      if (ident != null) {
        final path = catalog[ident];
        if (path != null && path.startsWith('/')) routes.add(path);
      } else if (quoted != null) {
        routes.add(quoted);
      }
    }
    return routes;
  }

  bool _hasEarlyReturnGuard(List<String> lines, String needle) {
    for (var i = 0; i < lines.length; i++) {
      final line = _stripLineComment(lines[i]);
      if (!line.contains('if') || !line.contains(needle)) continue;
      if (!line.contains('!')) continue;
      final window = lines.skip(i).take(6).map(_stripLineComment).join(' ');
      if (RegExp(r'\breturn\b').hasMatch(window)) return true;
    }
    return false;
  }

  List<(int, int)> _wrapIfRanges(List<String> lines, String needle) {
    final ranges = <(int, int)>[];
    final joined = lines.map(_stripLineComment).toList();
    for (var i = 0; i < joined.length; i++) {
      final line = joined[i];
      if (!line.contains('if') || !line.contains(needle)) continue;
      if (RegExp(r'if\s*\(\s*!').hasMatch(line.replaceAll(' ', ''))) {
        continue;
      }
      final rest = joined.skip(i).join('\n');
      final braceAt = rest.indexOf('{');
      if (braceAt >= 0 && braceAt < 40) {
        final end = _matchPair(joined, i, '{', '}');
        if (end != null) ranges.add((i, end));
        continue;
      }
      final end = _matchPair(joined, i + 1, '(', ')');
      if (end != null) ranges.add((i, end));
    }
    return ranges;
  }

  int? _matchPair(List<String> lines, int start, String open, String close) {
    var depth = 0;
    var seen = false;
    for (var i = start; i < lines.length; i++) {
      for (final rune in _stripLineComment(lines[i]).split('')) {
        if (rune == open) {
          depth += 1;
          seen = true;
        } else if (rune == close) {
          depth -= 1;
          if (seen && depth == 0) return i;
        }
      }
    }
    return null;
  }

  Map<String, String> _parseStringConsts(String source) {
    final map = <String, String>{};
    final re = RegExp(r"static const (?:\w+\s+)?(\w+)\s*=\s*'([^']+)'\s*;");
    for (final match in re.allMatches(source)) {
      map[match[1]!] = match[2]!;
    }
    return map;
  }

  _RouteTables _parseRouteTables(String source, Map<String, String> catalog) {
    final locals = _parseStringConsts(source);
    locals.addAll(catalog);

    Set<String> list(String name) {
      final match = RegExp(
        'static const(?: List<String>)? $name\\s*=\\s*\\[([\\s\\S]*?)\\];',
      ).firstMatch(source);
      if (match == null) return {};
      return _expandListBody(match[1]!, locals).toSet();
    }

    String? alias(String name) {
      final match = RegExp(
        'static const(?: \\w+)? $name\\s*=\\s*([\\w.]+)\\s*;',
      ).firstMatch(source);
      return match?[1];
    }

    final supporting = list('supportingPaths');
    final paid = list('paidPaths');
    final additional = list('additionalExactPaths');
    final prefixes = list('prefixPaths').toList();
    final quarantined = list('quarantinedExactPaths');
    final quarantinedParam = list('parameterizedQuarantinePaths');

    var primary = list('primaryShellPaths');
    if (primary.isEmpty) {
      final target = alias('primaryShellPaths');
      if (target == 'RouteCatalog.primaryRoutes') {
        primary = {
          for (final name in ['recordHome', 'archiveHome', 'accountHome'])
            if (catalog[name] != null) catalog[name]!,
        };
      }
    }

    return _RouteTables(
      allowlisted: {...supporting, ...paid, ...additional, ...primary},
      prefixes: prefixes,
      quarantined: quarantined,
    )..parameterized.addAll(quarantinedParam);
  }

  List<String> _expandListBody(String body, Map<String, String> consts) {
    final out = <String>[];
    for (final raw in body.split(',')) {
      var part = raw.trim();
      if (part.isEmpty || part.startsWith('//')) continue;
      part = part.replaceFirst(RegExp(r'//.*'), '').trim();
      if (part.isEmpty) continue;

      final quoted = RegExp(r"^'([^']+)'$").firstMatch(part);
      if (quoted != null) {
        out.add(quoted[1]!);
        continue;
      }

      final interp = RegExp(
        r"^'\$\{(\w+)\.(\w+)\}([^']*)'$",
      ).firstMatch(part);
      if (interp != null) {
        final prefix = consts[interp[2]!];
        if (prefix != null) out.add('$prefix${interp[3]}');
        continue;
      }

      final catalogIdent = RegExp(r'^RouteCatalog\.(\w+)$').firstMatch(part);
      if (catalogIdent != null) {
        final path = consts[catalogIdent[1]!];
        if (path != null) out.add(path);
        continue;
      }

      final ident = RegExp(r'^(\w+)$').firstMatch(part);
      if (ident != null) {
        final path = consts[ident[1]!];
        if (path != null) out.add(path);
      }
    }
    return out;
  }

  void _walkLib(void Function(File file) visit) {
    final lib = Directory('$root/lib');
    void walk(Directory dir) {
      for (final entity in dir.listSync(followLinks: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          if (entity.path.contains('/test/')) continue;
          visit(entity);
        } else if (entity is Directory) {
          walk(entity);
        }
      }
    }

    walk(lib);
  }

  String _stripLineComment(String line) {
    final i = line.indexOf('//');
    return i < 0 ? line : line.substring(0, i);
  }

  String _formatFlag(_Flag flag) {
    final define = flag.dartDefine == null ? '' : '  define=${flag.dartDefine}';
    return '${flag.name.padRight(24)} ${flag.kind.padRight(8)} '
        '${flag.resolved}$define';
  }

  String _rel(String path) =>
      path.startsWith('$root/') ? path.substring(root.length + 1) : path;
}

class _Flag {
  _Flag({
    required this.name,
    required this.kind,
    this.literalValue,
    this.getterExpr,
  });

  final String name;
  final String kind;
  final bool? literalValue;
  final String? getterExpr;

  String resolved = '';
  String? dartDefine;
  bool fromEnvironmentDefault = false;
  bool canEnableWithoutCodeChange = false;
}

class _EnvKey {
  _EnvKey(this.name, this.defaultValue);

  final String name;
  final bool defaultValue;
}

class _RouteTables {
  _RouteTables({
    required this.allowlisted,
    required this.prefixes,
    required this.quarantined,
  });

  final Set<String> allowlisted;
  final List<String> prefixes;
  final Set<String> quarantined;
  final parameterized = <String>{};

  bool isAllowlisted(String path) {
    if (allowlisted.contains(path)) return true;
    for (final prefix in prefixes) {
      if (path.startsWith(prefix)) return true;
    }
    return false;
  }
}

/// Parses `static const` string declarations out of Dart copy sources.
///
/// The duplication gates need to know not just *what* a copy file says but how
/// it says it: a heading that aliases another class's constant is the fix, and
/// a heading that retypes the same characters is the bug. Both look identical
/// once the program is running, so the distinction has to be read off the
/// source text.
///
/// Deliberately a small regex reader rather than the analyzer. It runs inside
/// a `flutter test` process over several hundred files, it only has to
/// understand the four shapes this repository actually writes, and every shape
/// it fails to understand is reported as [CopyDeclarationKind.unparsed] rather
/// than silently dropped.
library;

/// How a declaration produces its value.
enum CopyDeclarationKind {
  /// A plain string literal — `static const a = 'text';`, including the
  /// implicit concatenation of adjacent literals across lines.
  literal,

  /// A reference to another constant — `static const a = Other.b;`.
  /// Aliasing is the cheap path and must never fail a duplication gate.
  alias,

  /// A template built from other constants —
  /// `static const a = '${Other.b} ${Other.c}';`. Composition is aliasing with
  /// glue, so it is exempt for the same reason.
  composition,

  /// A shape this reader does not model. Reported, never assumed safe.
  unparsed,
}

/// One `static const` string declaration.
class CopyDeclaration {
  const CopyDeclaration({
    required this.path,
    required this.line,
    required this.name,
    required this.kind,
    required this.literalValue,
  });

  final String path;

  /// 1-based line of the `static const` keyword.
  final int line;
  final String name;
  final CopyDeclarationKind kind;

  /// The resolved text, for [CopyDeclarationKind.literal] only. Adjacent
  /// literals are already joined; escapes are left as written, which is fine
  /// because two declarations only match when their sources match.
  final String? literalValue;

  String get location => '$path:$line';

  @override
  String toString() => '$location $name (${kind.name})';
}

final RegExp _declarationStart = RegExp(
  r'^\s*static\s+(?:final\s+|const\s+)+'
  r'(?:String\s+|List<String>\s+)?'
  r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$',
);

final RegExp _identifierChain = RegExp(
  r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$',
);

/// A single-quoted literal with no interpolation and no escaped quote.
final RegExp _plainLiteral = RegExp(r"^'((?:[^'\\$]|\\.)*)'$");

/// Every `static const` string declaration in [source].
///
/// Declarations that span lines are read to their terminating `;`, which is
/// what makes adjacent-literal concatenation visible as one value.
List<CopyDeclaration> parseCopyDeclarations(String path, String source) {
  final declarations = <CopyDeclaration>[];
  final lines = source.split('\n');

  for (var index = 0; index < lines.length; index++) {
    final match = _declarationStart.firstMatch(lines[index]);
    if (match == null) continue;

    final buffer = StringBuffer(match.group(2)!);
    var cursor = index;
    while (!_statementEnds(buffer.toString()) && cursor + 1 < lines.length) {
      cursor++;
      buffer.write('\n${lines[cursor]}');
    }

    declarations.add(
      _classify(
        path: path,
        line: index + 1,
        name: match.group(1)!,
        initializer: buffer.toString(),
      ),
    );
    index = cursor;
  }

  return declarations;
}

bool _statementEnds(String text) => text.trimRight().endsWith(';');

CopyDeclaration _classify({
  required String path,
  required int line,
  required String name,
  required String initializer,
}) {
  var body = initializer.trim();
  if (body.endsWith(';')) body = body.substring(0, body.length - 1).trim();

  CopyDeclaration build(CopyDeclarationKind kind, [String? value]) =>
      CopyDeclaration(
        path: path,
        line: line,
        name: name,
        kind: kind,
        literalValue: value,
      );

  if (_identifierChain.hasMatch(body)) return build(CopyDeclarationKind.alias);

  final pieces = _splitAdjacentLiterals(body);
  if (pieces == null) return build(CopyDeclarationKind.unparsed);
  if (pieces.any((piece) => piece.contains(r'$'))) {
    return build(CopyDeclarationKind.composition);
  }

  final value = pieces
      .map((piece) => _plainLiteral.firstMatch(piece)!.group(1)!)
      .join();
  return build(CopyDeclarationKind.literal, value);
}

/// Splits `'a' 'b'` into its quoted pieces, or returns null if [body] is not
/// purely a run of single-quoted literals.
List<String>? _splitAdjacentLiterals(String body) {
  final pieces = <String>[];
  var rest = body.trim();

  while (rest.isNotEmpty) {
    if (!rest.startsWith("'")) return null;
    var end = 1;
    while (end < rest.length) {
      if (rest[end] == r'\') {
        end += 2;
        continue;
      }
      if (rest[end] == "'") break;
      end++;
    }
    if (end >= rest.length) return null;
    pieces.add(rest.substring(0, end + 1));
    rest = rest.substring(end + 1).trim();
  }

  if (pieces.isEmpty) return null;
  // A piece that interpolates is kept whole; the caller reads it as a
  // composition rather than trying to resolve it.
  if (pieces.any((piece) => !_plainLiteral.hasMatch(piece))) {
    return pieces.any((piece) => piece.contains(r'$')) ? pieces : null;
  }
  return pieces;
}

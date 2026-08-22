#!/usr/bin/env python3
import os
from pathlib import Path

ROOT = Path('/Users/chiragpatel/Projects/voice-memory')
OUT_DIR = Path.home() / 'Desktop' / 'upload1'
OUT_DIR.mkdir(parents=True, exist_ok=True)

EXCLUDE_DIR_NAMES = {
    'node_modules', '.git', '.dart_tool', 'build', 'Pods', '.gradle',
    '.next', 'dist', 'coverage', '.turbo', '__pycache__', '.idea',
    '.vscode', '.vercel', 'DerivedData', '.symlinks', 'ephemeral',
}
EXCLUDE_PATH_FRAGMENTS = (
    '/ios/Pods/', '/android/.gradle/', '/.dart_tool/', '/build/',
    '/node_modules/', '/.git/', '/.next/', '/dist/', '/coverage/',
)

BINARY_EXTENSIONS = {
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.bmp', '.svg',
    '.pdf', '.zip', '.gz', '.tar', '.bz2', '.7z', '.jar', '.aar', '.apk',
    '.aab', '.ipa', '.exe', '.dll', '.so', '.dylib', '.wasm', '.woff',
    '.woff2', '.ttf', '.otf', '.eot', '.mp3', '.mp4', '.m4a', '.mov',
    '.avi', '.mkv', '.flac', '.wav', '.aac', '.heic', '.DS_Store',
    '.tsbuildinfo', '.lock', '.map', '.bin', '.dat', '.pem', '.p12',
    '.keystore', '.jks', '.xcarchive', '.framework', '.a', '.o',
    '.class', '.pyc', '.pyo', '.pickle', '.sqlite', '.db',
}

TEXT_EXTENSIONS = {
    '.dart', '.ts', '.tsx', '.js', '.mjs', '.cjs', '.jsx',
    '.json', '.yaml', '.yml', '.md', '.sql', '.sh', '.bash', '.zsh',
    '.py', '.toml', '.xml', '.html', '.htm', '.css', '.scss', '.sass',
    '.less', '.swift', '.kt', '.kts', '.java', '.gradle', '.properties',
    '.plist', '.rb', '.rs', '.go', '.env', '.ini', '.cfg', '.conf',
    '.txt', '.csv', '.graphql', '.gql', '.proto', '.vue', '.svelte',
    '.dockerfile', '.gitignore', '.gitattributes', '.editorconfig',
    '.npmrc', '.nvmrc', '.prettierrc', '.eslintrc', '.mdc',
}

TEXT_FILENAMES = {
    'Dockerfile', 'Makefile', 'Gemfile', 'Rakefile', 'Procfile',
    'LICENSE', 'README', 'AGENTS.md', 'CLAUDE.md', '.env.example',
    'analysis_options.yaml', 'pubspec.yaml', 'Podfile', 'Gemfile.lock',
}

MAX_FILE_BYTES = 2 * 1024 * 1024


def is_text_candidate(path: Path) -> bool:
    if any(frag in str(path) for frag in EXCLUDE_PATH_FRAGMENTS):
        return False
    name = path.name
    if name in TEXT_FILENAMES or name.startswith('.env'):
        return True
    ext = path.suffix.lower()
    if ext in BINARY_EXTENSIONS:
        return False
    return ext in TEXT_EXTENSIONS


def read_text_file(path: Path) -> str | None:
    try:
        if path.stat().st_size > MAX_FILE_BYTES:
            return f"[SKIPPED: file exceeds {MAX_FILE_BYTES} bytes]\n"
        data = path.read_bytes()
        if b'\0' in data[:8192]:
            return None
        return data.decode('utf-8')
    except UnicodeDecodeError:
        try:
            return data.decode('latin-1')
        except Exception:
            return None
    except Exception as e:
        return f"[ERROR reading file: {e}]\n"


def classify(rel: str) -> int:
    if rel.startswith('apps/mobile/') or rel.startswith('packages/archiveme_research/'):
        return 0
    if rel.startswith(('apps/api/', 'apps/web/', 'packages/shared/', 'packages/ui/', 'lib/')):
        return 1
    return 2


def main() -> None:
    files: list[tuple[str, Path, int, int]] = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in sorted(dirnames) if d not in EXCLUDE_DIR_NAMES]
        for fn in filenames:
            p = Path(dirpath) / fn
            if not is_text_candidate(p):
                continue
            rel = str(p.relative_to(ROOT)).replace('\\', '/')
            if any(frag in rel for frag in EXCLUDE_PATH_FRAGMENTS):
                continue
            try:
                sz = p.stat().st_size
            except OSError:
                sz = 0
            files.append((rel, p, classify(rel), sz))

    files.sort(key=lambda x: x[0])
    print(f'Collected {len(files)} text source files')

    all_items = sorted(files, key=lambda x: (x[2], x[0]))
    final_buckets: list[list[tuple[str, Path]]] = [[], [], []]
    final_sizes = [0, 0, 0]

    for rel, p, _grp, sz in all_items:
        idx = min(range(3), key=lambda i: final_sizes[i])
        final_buckets[idx].append((rel, p))
        final_sizes[idx] += max(sz, 1)

    titles = [
        'project_export_1.txt — Flutter / mobile + balanced overflow',
        'project_export_2.txt — API / web / shared TypeScript + balanced overflow',
        'project_export_3.txt — docs / scripts / config / deferred code / remaining',
    ]

    for i in range(3):
        out_path = OUT_DIR / f'project_export_{i + 1}.txt'
        with out_path.open('w', encoding='utf-8') as out:
            out.write(f'# {titles[i]}\n')
            out.write('# Repository: voice-memory\n')
            out.write(f'# Files in this export: {len(final_buckets[i])}\n\n')
            for rel, p in final_buckets[i]:
                out.write(f'\n### File: {rel}\n\n')
                content = read_text_file(p)
                if content is None:
                    out.write('[SKIPPED: binary or unreadable file]\n')
                else:
                    out.write(content)
                    if not content.endswith('\n'):
                        out.write('\n')
        size = out_path.stat().st_size
        print(
            f'Wrote {out_path.name}: {len(final_buckets[i])} files, '
            f'{size / 1024 / 1024:.2f} MB'
        )

    manifest = OUT_DIR / 'export_manifest.txt'
    with manifest.open('w', encoding='utf-8') as m:
        m.write(f'Total source files exported: {len(files)}\n\n')
        for i in range(3):
            m.write(f'=== project_export_{i + 1}.txt ({len(final_buckets[i])} files) ===\n')
            for rel, _ in final_buckets[i]:
                m.write(rel + '\n')
            m.write('\n')

    exported = {rel for bucket in final_buckets for rel, _ in bucket}
    expected = {rel for rel, _, _, _ in files}
    print(
        f'Verification: expected={len(expected)} exported={len(exported)} '
        f'missing={len(expected - exported)} extra={len(exported - expected)}'
    )


if __name__ == '__main__':
    main()

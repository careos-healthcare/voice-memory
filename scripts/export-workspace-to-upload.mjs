#!/usr/bin/env node
/**
 * Exports text-based workspace files into exactly 3 plain-text bundles.
 */

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const WORKSPACE_ROOT = path.resolve(
  process.env.WORKSPACE_ROOT ?? path.join(import.meta.dirname, '..'),
);
const OUTPUT_DIR = path.join(os.homedir(), 'Desktop', 'upload1');
const OUTPUT_FILES = [
  path.join(OUTPUT_DIR, 'archiveme_export_1.txt'),
  path.join(OUTPUT_DIR, 'archiveme_export_2.txt'),
  path.join(OUTPUT_DIR, 'archiveme_export_3.txt'),
];

const EXCLUDED_DIR_NAMES = new Set([
  '.git',
  'node_modules',
  '.dart_tool',
  'build',
  'Pods',
  '.gradle',
  '.symlinks',
  '.fvm',
  'coverage',
  '.idea',
  '.vscode',
  'dist',
  '.next',
  '.turbo',
  'DerivedData',
  '__pycache__',
  '.pnpm-store',
  'vendor',
]);

const INCLUDED_EXTENSIONS = new Set([
  '.dart',
  '.ts',
  '.tsx',
  '.js',
  '.mjs',
  '.cjs',
  '.json',
  '.yaml',
  '.yml',
  '.md',
  '.txt',
  '.sh',
  '.bash',
  '.zsh',
  '.html',
  '.htm',
  '.css',
  '.scss',
  '.sass',
  '.less',
  '.xml',
  '.toml',
  '.ini',
  '.cfg',
  '.conf',
  '.env',
  '.sql',
  '.graphql',
  '.gql',
  '.proto',
  '.swift',
  '.kt',
  '.kts',
  '.gradle',
  '.properties',
  '.plist',
  '.xcconfig',
  '.cmake',
  '.mk',
  '.dockerfile',
  '.gitignore',
  '.gitattributes',
  '.editorconfig',
  '.prettierrc',
  '.eslintrc',
  '.nvmrc',
  '.ruby-version',
  '.python-version',
  '.tool-versions',
  '.lock',
]);

const EXCLUDED_EXTENSIONS = new Set([
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
  '.ico',
  '.icns',
  '.svg',
  '.mp3',
  '.wav',
  '.m4a',
  '.aac',
  '.ogg',
  '.flac',
  '.mp4',
  '.mov',
  '.avi',
  '.webm',
  '.mkv',
  '.ttf',
  '.otf',
  '.woff',
  '.woff2',
  '.eot',
  '.pdf',
  '.zip',
  '.tar',
  '.gz',
  '.bz2',
  '.xz',
  '.7z',
  '.rar',
  '.jar',
  '.aar',
  '.apk',
  '.ipa',
  '.exe',
  '.dll',
  '.so',
  '.dylib',
  '.bin',
  '.dat',
  '.db',
  '.sqlite',
  '.sqlite3',
  '.pem',
  '.p12',
  '.keystore',
  '.jks',
  '.class',
  '.wasm',
  '.map',
  '.lockb',
  '.pb',
  '.pb.go',
  '.DS_Store',
]);

const MAX_FILE_BYTES = 2 * 1024 * 1024;

function shouldIncludeFile(absPath, name) {
  const ext = path.extname(name).toLowerCase();
  const base = path.basename(name).toLowerCase();

  if (EXCLUDED_EXTENSIONS.has(ext)) return false;
  if (base === '.ds_store') return false;

  if (name.startsWith('.')) {
    if (EXCLUDED_EXTENSIONS.has(ext)) return false;
    return (
      INCLUDED_EXTENSIONS.has(ext) ||
      base === '.gitignore' ||
      base === '.gitattributes' ||
      base === '.editorconfig' ||
      base === '.dockerignore' ||
      base === '.env.example' ||
      base.startsWith('.env.')
    );
  }

  if (INCLUDED_EXTENSIONS.has(ext)) return true;
  if (base === 'dockerfile' || base.startsWith('dockerfile.')) return true;
  if (base === 'makefile' || base === 'gemfile' || base === 'rakefile') return true;
  if (base === 'license' || base === 'readme') return true;

  return false;
}

function isProbablyBinary(buffer) {
  const sample = buffer.subarray(0, Math.min(buffer.length, 8192));
  let suspicious = 0;
  for (const byte of sample) {
    if (byte === 0) return true;
    if (byte < 9 || (byte > 13 && byte < 32)) suspicious += 1;
  }
  return suspicious / sample.length > 0.1;
}

function walkDir(dir, files = []) {
  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return files;
  }

  for (const entry of entries) {
    const abs = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      if (EXCLUDED_DIR_NAMES.has(entry.name)) continue;
      if (dir.endsWith(`${path.sep}ios`) && entry.name === 'Pods') continue;
      if (dir.endsWith(`${path.sep}android`) && entry.name === '.gradle') continue;
      walkDir(abs, files);
      continue;
    }

    if (!entry.isFile()) continue;
    if (!shouldIncludeFile(abs, entry.name)) continue;

    files.push(abs);
  }

  return files;
}

function formatSection(relativePath, content) {
  return `### File: ${relativePath}\n${content}\n\n`;
}

function distributeEvenly(sections) {
  const buckets = [[], [], []];
  const sizes = [0, 0, 0];

  const sorted = [...sections].sort((a, b) => b.size - a.size);
  for (const section of sorted) {
    let target = 0;
    if (sizes[1] < sizes[target]) target = 1;
    if (sizes[2] < sizes[target]) target = 2;
    buckets[target].push(section);
    sizes[target] += section.size;
  }

  return buckets;
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });

  const allFiles = walkDir(WORKSPACE_ROOT).sort();
  const sections = [];
  let skippedBinary = 0;
  let skippedLarge = 0;
  let readErrors = 0;

  for (const absPath of allFiles) {
    const relativePath = path.relative(WORKSPACE_ROOT, absPath).split(path.sep).join('/');
    let stat;
    try {
      stat = fs.statSync(absPath);
    } catch {
      readErrors += 1;
      continue;
    }

    if (stat.size > MAX_FILE_BYTES) {
      skippedLarge += 1;
      continue;
    }

    let buffer;
    try {
      buffer = fs.readFileSync(absPath);
    } catch {
      readErrors += 1;
      continue;
    }

    if (isProbablyBinary(buffer)) {
      skippedBinary += 1;
      continue;
    }

    const content = buffer.toString('utf8');
    const sectionText = formatSection(relativePath, content);
    sections.push({
      relativePath,
      text: sectionText,
      size: Buffer.byteLength(sectionText, 'utf8'),
    });
  }

  const buckets = distributeEvenly(sections);

  for (let i = 0; i < OUTPUT_FILES.length; i += 1) {
    const body = buckets[i].map((section) => section.text).join('');
    fs.writeFileSync(OUTPUT_FILES[i], body, 'utf8');
  }

  const summary = {
    workspaceRoot: WORKSPACE_ROOT,
    outputDir: OUTPUT_DIR,
    filesScanned: allFiles.length,
    filesExported: sections.length,
    skippedBinary,
    skippedLarge,
    readErrors,
    outputs: OUTPUT_FILES.map((filePath, index) => {
      const stat = fs.statSync(filePath);
      return {
        file: filePath,
        exists: fs.existsSync(filePath),
        sections: buckets[index].length,
        sizeBytes: stat.size,
        sizeHuman: formatBytes(stat.size),
      };
    }),
  };

  console.log(JSON.stringify(summary, null, 2));
}

main();

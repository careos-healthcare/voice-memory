import 'dart:io';

import 'package:archive/archive.dart';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:path/path.dart' as p;

const _vectorVersion = '1.0.0';
const _releaseBase =
    'https://github.com/sqliteai/sqlite-vector/releases/download/$_vectorVersion';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;

    final codeConfig = input.config.code;
    final os = codeConfig.targetOS;
    final arch = codeConfig.targetArchitecture;

    final release = _resolveReleaseAsset(os, arch, codeConfig);
    if (release == null) {
      throw UnsupportedError(
        'sqlite-vector native asset is not supported on $os $arch.',
      );
    }

    final sharedOutputDir = input.outputDirectoryShared;
    await Directory.fromUri(sharedOutputDir).create(recursive: true);

    final assetUri = sharedOutputDir.resolve(release.outputFileName);
    var assetFile = File.fromUri(assetUri);

    if (!assetFile.existsSync()) {
      await _downloadZipMember(
        zipUrl: '$_releaseBase/${release.zipName}',
        memberName: release.memberName,
        destination: assetFile,
      );
    }

    assetFile = await _prepareAssetFile(
      input: input,
      os: os,
      arch: arch,
      config: codeConfig,
      file: assetFile,
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/native/sqlite_vector_extension.dart',
        linkMode: DynamicLoadingBundled(),
        file: assetFile.uri,
      ),
    );
  });
}

class _ReleaseAsset {
  const _ReleaseAsset({
    required this.zipName,
    required this.memberName,
    required this.outputFileName,
  });

  final String zipName;
  final String memberName;
  final String outputFileName;
}

_ReleaseAsset? _resolveReleaseAsset(
  OS os,
  Architecture arch,
  CodeConfig config,
) {
  if (os == OS.android) {
    return switch (arch) {
      Architecture.arm64 => const _ReleaseAsset(
        zipName: 'vector-android-arm64-v8a-$_vectorVersion.zip',
        memberName: 'vector.so',
        outputFileName: 'vector_android_arm64.so',
      ),
      Architecture.arm => const _ReleaseAsset(
        zipName: 'vector-android-armeabi-v7a-$_vectorVersion.zip',
        memberName: 'vector.so',
        outputFileName: 'vector_android_arm.so',
      ),
      Architecture.x64 => const _ReleaseAsset(
        zipName: 'vector-android-x86_64-$_vectorVersion.zip',
        memberName: 'vector.so',
        outputFileName: 'vector_android_x64.so',
      ),
      _ => null,
    };
  }

  if (os == OS.iOS) {
    final sdk = config.iOS.targetSdk;
    if (sdk == IOSSdk.iPhoneOS) {
      return const _ReleaseAsset(
        zipName: 'vector-ios-$_vectorVersion.zip',
        memberName: 'vector.dylib',
        outputFileName: 'vector_ios_arm64.dylib',
      );
    }
    return const _ReleaseAsset(
      zipName: 'vector-ios-sim-$_vectorVersion.zip',
      memberName: 'vector.dylib',
      outputFileName: 'vector_ios_sim.dylib',
    );
  }

  if (os == OS.macOS) {
    return switch (arch) {
      Architecture.arm64 => const _ReleaseAsset(
        zipName: 'vector-macos-arm64-$_vectorVersion.zip',
        memberName: 'vector.dylib',
        outputFileName: 'vector_mac_arm64.dylib',
      ),
      Architecture.x64 => const _ReleaseAsset(
        zipName: 'vector-macos-x86_64-$_vectorVersion.zip',
        memberName: 'vector.dylib',
        outputFileName: 'vector_mac_x64.dylib',
      ),
      _ => null,
    };
  }

  if (os == OS.linux) {
    return switch (arch) {
      Architecture.x64 => const _ReleaseAsset(
        zipName: 'vector-linux-x86_64-$_vectorVersion.zip',
        memberName: 'vector.so',
        outputFileName: 'vector_linux_x64.so',
      ),
      Architecture.arm64 => const _ReleaseAsset(
        zipName: 'vector-linux-arm64-$_vectorVersion.zip',
        memberName: 'vector.so',
        outputFileName: 'vector_linux_arm64.so',
      ),
      _ => null,
    };
  }

  if (os == OS.windows) {
    return switch (arch) {
      Architecture.x64 => const _ReleaseAsset(
        zipName: 'vector-windows-x86_64-$_vectorVersion.zip',
        memberName: 'vector.dll',
        outputFileName: 'vector_windows_x64.dll',
      ),
      _ => null,
    };
  }

  return null;
}

Future<void> _downloadZipMember({
  required String zipUrl,
  required String memberName,
  required File destination,
}) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(zipUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download sqlite-vector asset ($zipUrl): HTTP ${response.statusCode}',
        uri: Uri.parse(zipUrl),
      );
    }

    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
    }
    final archive = ZipDecoder().decodeBytes(bytes);
    final member = archive.files.firstWhere(
      (file) => p.posix.basename(file.name) == memberName,
      orElse: () => throw StateError(
        'Archive $zipUrl did not contain expected member $memberName.',
      ),
    );

    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(member.content as List<int>, flush: true);
  } finally {
    client.close(force: true);
  }
}

Future<File> _prepareAssetFile({
  required BuildInput input,
  required OS os,
  required Architecture arch,
  required CodeConfig config,
  required File file,
}) async {
  if (os != OS.iOS || config.iOS.targetSdk == IOSSdk.iPhoneOS) {
    return file;
  }

  final thinArch = switch (arch) {
    Architecture.arm64 => 'arm64',
    Architecture.x64 => 'x86_64',
    _ => null,
  };
  if (thinArch == null) {
    return file;
  }

  final outputName = 'vector_ios_sim_$thinArch.dylib';
  final outputFile = File.fromUri(input.outputDirectory.resolve(outputName));
  await outputFile.parent.create(recursive: true);

  final result = await Process.run('/usr/bin/lipo', [
    file.path,
    '-thin',
    thinArch,
    '-output',
    outputFile.path,
  ]);
  if (result.exitCode != 0) {
    throw StateError(
      'Failed to thin sqlite-vector iOS simulator binary for $thinArch: '
      '${result.stderr}',
    );
  }

  return outputFile;
}

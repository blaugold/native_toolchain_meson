import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_toolchain_meson/src/vendor/native_toolchain_c/utils/run_process.dart';

const repo = 'https://github.com/blaugold/native';
const ref = 'native_toolchain_meson_tools';
const destination = 'lib/src/vendor/native_toolchain_c';
const sourceBasePath = 'pkgs/native_toolchain_c/lib/src';
final sourcePatterns = [
  RegExp('tool/.*'),
  RegExp('native_toolchain/.*'),
  RegExp('utils/.*'),
  'cbuilder/compiler_resolver.dart',
  'cbuilder/linkmode.dart',
];

void main() async {
  final logger = Logger('')..onRecord.listen((record) => print(record.message));

  final tempDirectory = Directory.systemTemp.createTempSync();

  try {
    await runProcess(
      executable: Uri.file('git'),
      arguments: [
        'clone',
        '--depth',
        '1',
        '--branch',
        ref,
        repo,
        tempDirectory.path
      ],
      logger: logger,
    );

    final sourceDirectory = Directory('${tempDirectory.path}/$sourceBasePath');
    await for (final file in sourceDirectory.list(recursive: true)) {
      if (file is File) {
        final relativePath =
            file.path.substring(sourceDirectory.path.length + 1);
        if (sourcePatterns
            .any((pattern) => pattern.matchAsPrefix(relativePath) != null)) {
          final destinationFile = File('$destination/$relativePath');
          await destinationFile.parent.create(recursive: true);
          await file.copy(destinationFile.path);
        }
      }
    }
  } finally {
    tempDirectory.deleteSync(recursive: true);
  }
}

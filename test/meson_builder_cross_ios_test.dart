@TestOn('mac-os')
@OnPlatform({
  'mac-os': Timeout.factor(2),
})
library;

import 'dart:io';

import 'package:native_toolchain_meson/src/meson_builder.dart';
import 'package:native_toolchain_meson/src/vendor/native_toolchain_c/cbuilder/linkmode.dart';
import 'package:native_toolchain_meson/src/vendor/native_toolchain_c/utils/run_process.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  if (!Platform.isMacOS) {
    // Avoid needing status files on Dart SDK CI.
    return;
  }

  const targets = [
    Target.iOSArm64,
    Target.iOSX64,
  ];

  // Dont include 'mach-o' or 'Mach-O', different spelling is used.
  const objdumpFileFormat = {
    Target.iOSArm64: 'arm64',
    Target.iOSX64: '64-bit x86-64',
  };

  const name = 'add';

  for (final linkModePreference in LinkModePreference.values) {
    for (final targetIOSSdk in IOSSdk.values) {
      for (final target in targets) {
        if (target == Target.iOSX64 && targetIOSSdk == IOSSdk.iPhoneOS) {
          continue;
        }

        final libName =
            target.os.libraryFileName(name, getLinkMode(linkModePreference));

        final suffix = testSuffix([linkModePreference, target, targetIOSSdk]);

        test('MesonBuilder library$suffix', () async {
          final tempUri = await tempDirForTest();
          final tempUri2 = await tempDirForTest();

          final buildConfigBuilder = BuildConfigBuilder()
            ..setupHookConfig(
              supportedAssetTypes: [CodeAsset.type],
              packageName: 'dummy',
              packageRoot: mesonAddLibProjectUri,
              targetOS: target.os,
              buildMode: BuildMode.release,
            )
            ..setupBuildConfig(
              linkingEnabled: false,
              dryRun: false,
            )
            ..setupCodeConfig(
              targetArchitecture: target.architecture,
              linkModePreference: linkModePreference,
              targetIOSSdk: targetIOSSdk,
            );
          buildConfigBuilder.setupBuildRunConfig(
            outputDirectory: tempUri,
            outputDirectoryShared: tempUri2,
          );
          final buildConfig = BuildConfig(buildConfigBuilder.json);
          final buildOutput = BuildOutputBuilder();

          final mesonBuilder = MesonBuilder.library(
            assetName: name,
            project: 'meson_project',
            target: name,
          );
          await mesonBuilder.run(
            config: buildConfig,
            output: buildOutput,
            logger: logger,
          );

          final libUri = tempUri.resolve(libName);
          final objdumpResult = await runProcess(
            executable: Uri.file('objdump'),
            arguments: ['-t', libUri.path],
            logger: logger,
          );
          expect(objdumpResult.exitCode, 0);
          final machine = objdumpResult.stdout
              .split('\n')
              .firstWhere((e) => e.contains('file format'));
          expect(machine, contains(objdumpFileFormat[target]));

          final otoolResult = await runProcess(
            executable: Uri.file('otool'),
            arguments: ['-l', libUri.path],
            logger: logger,
          );
          expect(otoolResult.exitCode, 0);
          if (targetIOSSdk == IOSSdk.iPhoneOS || target == Target.iOSX64) {
            // The x64 simulator behaves as device, presumably because the
            // devices are never x64.
            expect(otoolResult.stdout, contains('LC_VERSION_MIN_IPHONEOS'));
            expect(otoolResult.stdout, isNot(contains('LC_BUILD_VERSION')));
          } else {
            expect(
                otoolResult.stdout, isNot(contains('LC_VERSION_MIN_IPHONEOS')));
            expect(otoolResult.stdout, contains('LC_BUILD_VERSION'));
            final platform = otoolResult.stdout
                .split('\n')
                .firstWhere((e) => e.contains('platform'));
            const platformIosSimulator = 7;
            expect(platform, contains(platformIosSimulator.toString()));
          }

          if (linkModePreference == LinkModePreference.dynamic) {
            final libInstallName = await runOtoolInstallName(libUri, libName);
            expect(libInstallName, '@rpath/$libName');
          }
        });
      }
    }
  }
}

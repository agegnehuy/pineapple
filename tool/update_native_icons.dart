import 'dart:io';
import 'dart:convert';

/// AppIcon is already registered in every Runner build configuration.
/// Version 0.14.4 of the icon generator also rewrites a Swift asset-symbol
/// boolean as an icon name. Preserve the existing Xcode project while
/// regenerating only the native image assets and Android resources.
Future<void> main() async {
  final project = File('ios/Runner.xcodeproj/project.pbxproj');
  final original = await project.readAsBytes();
  ProcessResult result;
  try {
    result = await Process.run(
      Platform.resolvedExecutable,
      ['run', 'flutter_launcher_icons'],
      runInShell: Platform.isWindows,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } finally {
    await project.writeAsBytes(original);
  }
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}

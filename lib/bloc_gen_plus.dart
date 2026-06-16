import 'dart:async';
import 'dart:io';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'src/utils.dart';
import 'src/bloc_generator.dart';
import 'src/i18n_generator.dart';

Builder i18nBuilder(BuilderOptions options) => I18nBuilder();
Builder blocBuilder(BuilderOptions options) => BlocBuilder();

class I18nBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
    '.yaml': ['.i18n.dart']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final content = await buildStep.readAsString(inputId);
    final yamlDir = p.dirname(p.join(Directory.current.path, inputId.path));

    final oldWriter = fileWriter;
    final futures = <Future<void>>[];

    fileWriter = (dest, fileContent, overwrite) {
      final packageRoot = Directory.current.path;
      final relPath = p.relative(dest, from: packageRoot);
      final outputId = AssetId(inputId.package, relPath);

      bool isAllowed = false;
      try {
        isAllowed = buildStep.allowedOutputs.contains(outputId);
      } catch (_) {}

      if (isAllowed) {
        futures.add(buildStep.writeAsString(outputId, fileContent));
      } else {
        // Fallback to direct file writing since translation files (e.g. English.dart)
        // are dynamic and cannot be declared statically in buildExtensions.
        final file = File(dest);
        if (overwrite || !file.existsSync()) {
          final dir = file.parent;
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          file.writeAsStringSync(fileContent);
        }
      }
    };

    try {
      generateI18nMultiFile(
        content,
        inputId.path,
        yamlDir,
        '',
        '',
        '',
        false,
        '--build',
      );
      await Future.wait(futures);
      try {
        File('${inputId.path}.modified').writeAsStringSync("Don't change\n${DateTime.now()}\n");
      } catch (_) {}
    } finally {
      fileWriter = oldWriter;
    }

    final path = inputId.path;
    final newPath = path.substring(0, path.length - '.yaml'.length) + '.i18n.dart';
    final outputId = AssetId(inputId.package, newPath);
    await buildStep.writeAsString(
      outputId,
      '// Generated i18n marker file for ${inputId.path}\n// Timestamp: ${DateTime.now()}\n',
    );
  }
}

class BlocBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
    'demo.yaml': [
      'demobloc/demo.dart',
      'demobloc/demo.s.dart',
      'demobloc/demo.e.dart',
      'demobloc/demo.b.dart',
      'demobloc/demo.d.dart',
      'demobloc/demo.c.dart',
    ],
    'demo_parent.yaml': [
      'demo_parent/demo_parent.dart',
      'demo_parent/demo_parent.s.dart',
      'demo_parent/demo_parent.e.dart',
      'demo_parent/demo_parent.b.dart',
      'demo_parent/demo_parent.d.dart',
      'demo_parent/demo_parent.c.dart',
    ],
    'state_only.yaml': [
      'demostate/demo.dart',
      'demostate/demo.s.dart',
      'demostate/demo.e.dart',
      'demostate/demo.b.dart',
      'demostate/demo.d.dart',
      'demostate/demo.c.dart',
    ],
    'event_only.yaml': [
      'demoevent/demo.dart',
      'demoevent/demo.s.dart',
      'demoevent/demo.e.dart',
      'demoevent/demo.b.dart',
      'demoevent/demo.d.dart',
      'demoevent/demo.c.dart',
    ],
    '.yaml': [
      '.dart',
      '.s.dart',
      '.e.dart',
      '.b.dart',
      '.d.dart',
      '.c.dart',
    ],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final content = await buildStep.readAsString(inputId);
    final yamlDir = p.dirname(p.join(Directory.current.path, inputId.path));

    final oldWriter = fileWriter;
    final futures = <Future<void>>[];

    fileWriter = (dest, fileContent, overwrite) {
      final packageRoot = Directory.current.path;
      final relPath = p.relative(dest, from: packageRoot);
      final outputId = AssetId(inputId.package, relPath);

      bool isAllowed = false;
      try {
        isAllowed = buildStep.allowedOutputs.contains(outputId);
      } catch (_) {}

      if (isAllowed) {
        futures.add(buildStep.writeAsString(outputId, fileContent));
      } else {
        // Fallback to direct file writing
        final file = File(dest);
        if (overwrite || !file.existsSync()) {
          final dir = file.parent;
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          file.writeAsStringSync(fileContent);
        }
      }
    };

    try {
      final doc = loadYaml(content);
      if (doc is Map) {
        final data = convertYamlMap(doc as YamlMap);
        final args = GeneratorArgs();
        allGen(args, data, yamlDir);
      }
      await Future.wait(futures);
      try {
        File('${inputId.path}.modified').writeAsStringSync("Don't change\n${DateTime.now()}\n");
      } catch (_) {}
    } finally {
      fileWriter = oldWriter;
    }
  }
}

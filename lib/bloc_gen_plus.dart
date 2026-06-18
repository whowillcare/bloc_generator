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

String? _rootPackageName;

String _getRootPackageName() {
  if (_rootPackageName != null) return _rootPackageName!;
  try {
    final pubspecFile = File('pubspec.yaml');
    if (pubspecFile.existsSync()) {
      final doc = loadYaml(pubspecFile.readAsStringSync());
      if (doc is Map && doc.containsKey('name')) {
        _rootPackageName = doc['name']?.toString();
      }
    }
  } catch (_) {}
  return _rootPackageName ??= '';
}

class I18nBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
    '.yaml': ['.i18n.dart']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final rootPackage = _getRootPackageName();
    if (rootPackage.isNotEmpty && inputId.package != rootPackage) {
      return;
    }
    final outputId = inputId.changeExtension('.i18n.dart');

    // First read the content of the file to see if it is a main i18n file
    String content;
    Map<String, dynamic> data;
    try {
      content = await buildStep.readAsString(inputId);
      final doc = loadYaml(content);
      if (doc is! Map || !doc.containsKey('Languages')) {
        // Not a main i18n file, write a dummy marker and return early
        await buildStep.writeAsString(
          outputId,
          '// Not a main i18n file\n',
        );
        return;
      }
      data = convertYamlMap(doc as YamlMap);
    } catch (_) {
      // If parsing fails or we cannot read, write a dummy marker
      await buildStep.writeAsString(
        outputId,
        '// Not a main i18n file\n',
      );
      return;
    }

    // Preload the included files so build_runner tracks them as dependencies
    await preloadI18nReferencedFiles(buildStep, data);

    if (!shouldBuild(inputId.path, verbose: false)) {
      // If we shouldn't build, try to keep the existing content of the marker file
      // to avoid triggering downstream builders or indicating changes.
      String existingContent = '';
      try {
        if (await buildStep.canRead(outputId)) {
          existingContent = await buildStep.readAsString(outputId);
        }
      } catch (_) {}
      if (existingContent.isNotEmpty) {
        await buildStep.writeAsString(outputId, existingContent);
      } else {
        await buildStep.writeAsString(
          outputId,
          '// Generated i18n marker file for ${inputId.path}\n',
        );
      }
      return;
    }

    final yamlDir = p.dirname(p.join(Directory.current.path, inputId.path));

    final oldWriter = fileWriter;
    final futures = <Future<void>>[];

    fileWriter = (dest, fileContent, overwrite) {
      final packageRoot = Directory.current.path;
      final relPath = p.relative(dest, from: packageRoot);
      final outId = AssetId(inputId.package, relPath);

      bool isAllowed = false;
      try {
        isAllowed = buildStep.allowedOutputs.contains(outId);
      } catch (_) {}

      if (isAllowed) {
        futures.add(buildStep.writeAsString(outId, fileContent));
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
        writeMark(inputId.path);
      } catch (_) {}
    } finally {
      fileWriter = oldWriter;
    }

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
    final rootPackage = _getRootPackageName();
    if (rootPackage.isNotEmpty && inputId.package != rootPackage) {
      return;
    }
    if (!shouldBuild(inputId.path, verbose: false)) {
      return;
    }
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
        await preloadReferencedFiles(buildStep, data);
        final args = GeneratorArgs();
        allGen(args, data, yamlDir);
      }
      await Future.wait(futures);
      try {
        writeMark(inputId.path);
      } catch (_) {}
    } finally {
      fileWriter = oldWriter;
    }
  }
}

Future<void> preloadI18nReferencedFiles(BuildStep buildStep, Map<String, dynamic> data) async {
  final inputId = buildStep.inputId;
  final yamlDir = p.dirname(inputId.path);
  final settings = data['settings'] as Map? ?? {};
  final includeSubdir = settings['include']?.toString();
  if (includeSubdir != null && includeSubdir.isNotEmpty) {
    final includePath = p.normalize(p.join(yamlDir, includeSubdir));
    final includeDir = Directory(p.join(Directory.current.path, includePath));
    if (includeDir.existsSync()) {
      try {
        final files = includeDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
            .toList();
        for (final file in files) {
          final relPath = p.relative(file.path, from: Directory.current.path);
          final assetId = AssetId(inputId.package, relPath);
          if (await buildStep.canRead(assetId)) {
            final fileContent = await buildStep.readAsString(assetId);
            final absolutePath = p.canonicalize(file.path);
            inMemoryFiles[absolutePath] = fileContent;
          }
        }
      } catch (_) {}
    }
  }
}

Future<void> preloadReferencedFiles(BuildStep buildStep, Map<String, dynamic> data) async {
  final inputId = buildStep.inputId;
  final yamlDir = p.dirname(inputId.path);
  final path = data['path']?.toString() ?? '';
  final part = data['part']?.toString() ?? '';
  
  String resolveFullname(String dest, {String mypart = ''}) {
    final baseDir = p.dirname(p.normalize(p.join(yamlDir, path, dest)));
    final filename = mypart.isNotEmpty ? mypart : part;
    return p.normalize(p.join(baseDir, filename));
  }

  final filesToPreload = <String>[];

  final stateData = data['state'] as Map?;
  final eventData = data['event'] as Map?;
  final blocData = data['bloc'] as Map?;
  
  final stateDest = stateData?['dest']?.toString() ?? '';
  final eventDest = eventData?['dest']?.toString() ?? '';
  final blocDest = blocData?['dest']?.toString() ?? '';
  
  String getDestPath(String dest) {
    if (dest.isEmpty) return '';
    var resolvedDest = dest;
    if (resolvedDest.startsWith('.')) {
      if (part.isNotEmpty) {
        final partName = p.basenameWithoutExtension(part);
        resolvedDest = partName + resolvedDest;
      }
    }
    return p.normalize(p.join(yamlDir, path, resolvedDest));
  }

  final resolvedStateDest = getDestPath(stateDest);
  final resolvedEventDest = getDestPath(eventDest);
  final resolvedBlocDest = getDestPath(blocDest);

  if (part.isNotEmpty) {
    final mainDest = resolvedBlocDest.isNotEmpty ? resolvedBlocDest : (resolvedStateDest.isNotEmpty ? resolvedStateDest : resolvedEventDest);
    if (mainDest.isNotEmpty) {
      final mainFullname = resolveFullname(mainDest);
      filesToPreload.add(mainFullname);
    }
  }
  
  if (resolvedStateDest.isNotEmpty) filesToPreload.add(resolvedStateDest);
  if (resolvedEventDest.isNotEmpty) filesToPreload.add(resolvedEventDest);
  if (resolvedBlocDest.isNotEmpty) filesToPreload.add(resolvedBlocDest);

  if (stateData != null && stateData.containsKey('parent')) {
    final parentFile = stateData['parent']?.toString() ?? '';
    if (parentFile.isNotEmpty) {
      final mainDest = resolvedBlocDest.isNotEmpty ? resolvedBlocDest : resolvedStateDest;
      if (mainDest.isNotEmpty) {
        final parentPath = resolveFullname(mainDest, mypart: parentFile);
        filesToPreload.add(parentPath);
      }
    }
  }

  if (blocData != null && blocData.containsKey('repo_file')) {
    final repoFile = blocData['repo_file']?.toString() ?? '';
    if (repoFile.isNotEmpty) {
      final repoPath = p.normalize(p.join(yamlDir, path, repoFile));
      filesToPreload.add(repoPath);
    }
  }

  for (final relPath in filesToPreload) {
    final assetId = AssetId(inputId.package, relPath);
    try {
      if (await buildStep.canRead(assetId)) {
        final fileContent = await buildStep.readAsString(assetId);
        final absolutePath = p.canonicalize(p.join(Directory.current.path, relPath));
        inMemoryFiles[absolutePath] = fileContent;
      }
    } catch (_) {}
  }
}

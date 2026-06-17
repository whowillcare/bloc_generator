import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

class DartTemplate {
  final String template;
  final String delimiter;

  DartTemplate(this.template, {this.delimiter = '%'});

  String safeSubstitute(Map<String, dynamic> mapping) {
    final escapedDelimiter = RegExp.escape(delimiter);
    
    // Pattern matches:
    // 1. Escaped delimiter (e.g. %% or $@$@)
    // 2. Delimiter followed by braced variable (e.g. %{name} or $@{name})
    // 3. Delimiter followed by simple word variable (e.g. %name or $@name)
    final pattern = RegExp(
      '$escapedDelimiter(?:($escapedDelimiter)|\\{([^}]+)\\}|([a-zA-Z0-9_]+))',
    );

    return template.replaceAllMapped(pattern, (match) {
      if (match.group(1) != null) {
        return delimiter;
      }
      final varName = match.group(2) ?? match.group(3);
      if (varName != null && mapping.containsKey(varName)) {
        return mapping[varName].toString();
      }
      return match.group(0)!;
    });
  }
}

Never error(String msg) {
  stderr.writeln(msg);
  exit(-1);
}

Map<String, dynamic> convertYamlMap(YamlMap yamlMap) {
  final map = <String, dynamic>{};
  for (final key in yamlMap.keys) {
    final value = yamlMap[key];
    if (value is YamlMap) {
      map[key.toString()] = convertYamlMap(value);
    } else if (value is YamlList) {
      map[key.toString()] = convertYamlList(value);
    } else {
      map[key.toString()] = value;
    }
  }
  return map;
}

List<dynamic> convertYamlList(YamlList yamlList) {
  final list = <dynamic>[];
  for (final item in yamlList) {
    if (item is YamlMap) {
      list.add(convertYamlMap(item));
    } else if (item is YamlList) {
      list.add(convertYamlList(item));
    } else {
      list.add(item);
    }
  }
  return list;
}

typedef FileWriter = void Function(String dest, String content, bool overwrite);

FileWriter fileWriter = defaultFileWriter;

void defaultFileWriter(String dest, String content, bool overwrite) {
  if (dest.isEmpty) return;
  final file = File(dest);
  if (overwrite || !file.existsSync()) {
    final dir = file.parent;
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    file.writeAsStringSync(content);
  }
}

final Map<String, String> inMemoryFiles = {};

void writeContent(String dest, String content, {bool overwrite = true}) {
  inMemoryFiles[dest] = content;
  fileWriter(dest, content, overwrite);
}

String? loadContent(String path) {
  if (path.isEmpty) return null;
  if (inMemoryFiles.containsKey(path)) {
    return inMemoryFiles[path];
  }
  final file = File(path);
  if (file.existsSync()) {
    return file.readAsStringSync();
  }
  return null;
}

bool fileExists(String path) {
  if (path.isEmpty) return false;
  if (inMemoryFiles.containsKey(path)) return true;
  return File(path).existsSync();
}

bool shouldBuild(String yamlPath, {bool verbose = true}) {
  final markFile = File('$yamlPath.modified');
  if (!markFile.existsSync()) return true;

  final yamlStat = File(yamlPath).statSync();
  final markStat = markFile.statSync();

  if (yamlStat.modified.isAfter(markStat.modified)) {
    if (verbose) {
      print("You have changed to $yamlPath");
    }
    return true;
  }

  try {
    final file = File(yamlPath);
    if (file.existsSync()) {
      final doc = loadYaml(file.readAsStringSync());
      if (doc is Map) {
        final data = convertYamlMap(doc as YamlMap);
        final yamlDir = p.dirname(yamlPath);
        
        final filesToCheck = <String>[];
        
        if (data.containsKey('Languages')) {
          final settings = data['settings'] as Map? ?? {};
          final helperName = settings['helper']?.toString() ?? 'S';
          final defaultCls = settings['default_class']?.toString() ?? 'TI';
          final languages = data['Languages'] as List?;
          
          filesToCheck.add(p.normalize(p.join(yamlDir, '$helperName.dart')));
          filesToCheck.add(p.normalize(p.join(yamlDir, '$defaultCls.dart')));
          if (languages != null) {
            for (final lang in languages) {
              if (lang is Map) {
                final name = lang['name']?.toString() ?? '';
                if (name.isNotEmpty) {
                  filesToCheck.add(p.normalize(p.join(yamlDir, '$name.dart')));
                }
              }
            }
          }
          final includeSubdir = settings['include']?.toString();
          if (includeSubdir != null && includeSubdir.isNotEmpty) {
            final includePath = p.normalize(p.join(yamlDir, includeSubdir));
            final includeDir = Directory(includePath);
            if (includeDir.existsSync()) {
              try {
                final includedFiles = includeDir
                    .listSync(recursive: true)
                    .whereType<File>()
                    .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
                    .toList();
                for (final f in includedFiles) {
                  final fStat = f.statSync();
                  if (fStat.modified.isAfter(markStat.modified)) {
                    if (verbose) {
                      print("You have changed to included file: ${f.path}");
                    }
                    return true;
                  }
                }
              } catch (_) {}
            }
          }
        } else {
          final path = data['path']?.toString() ?? '';
          final part = data['part']?.toString() ?? '';
          
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
          
          if (resolvedStateDest.isNotEmpty) filesToCheck.add(resolvedStateDest);
          if (resolvedEventDest.isNotEmpty) filesToCheck.add(resolvedEventDest);
          if (resolvedBlocDest.isNotEmpty) filesToCheck.add(resolvedBlocDest);
          
          if (part.isNotEmpty) {
            final mainDest = resolvedBlocDest.isNotEmpty ? resolvedBlocDest : (resolvedStateDest.isNotEmpty ? resolvedStateDest : resolvedEventDest);
            if (mainDest.isNotEmpty) {
              final baseDir = p.dirname(mainDest);
              filesToCheck.add(p.normalize(p.join(baseDir, part)));
            }
          }
        }

        for (final pathToCheck in filesToCheck) {
          if (!File(pathToCheck).existsSync()) {
            if (verbose) {
              print("Missing generated file: $pathToCheck");
            }
            return true;
          }
        }
      }
    }
  } catch (e) {
    return true;
  }

  if (verbose) {
    print("$yamlPath build is still valid");
  }
  return false;
}

void writeMark(String yamlPath) {
  final markFile = File('$yamlPath.modified');
  markFile.writeAsStringSync("Don't change\n${DateTime.now()}\n");
}


import 'dart:io';
import 'package:yaml/yaml.dart';

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

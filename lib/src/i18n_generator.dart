import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'utils.dart';



String getArgs(List<String> args) {
  final ret = <String>[];
  const defType = "String";
  for (final arg in args) {
    final parts = arg.split('@');
    var tp = defType;
    var vn = arg;
    if (parts.length == 2) {
      tp = parts[0];
      vn = parts[1];
    }
    ret.add("$tp $vn");
  }
  return ret.join(",");
}

String generateInterface(String name, [List<String>? args]) {
  if (args != null && args.isNotEmpty) {
    final argname = getArgs(args);
    return "  String $name($argname) => '';";
  } else {
    return "  String get $name => '';";
  }
}

String escapeString(String val) {
  return val
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t')
      .replaceAll('\$', '\\\$');
}

String generateOverride(String name, dynamic value, [List<String>? args]) {
  final hasArgs = args != null && args.isNotEmpty;
  if (!hasArgs) {
    return '  @override String get $name => "${escapeString(value.toString())}";';
  }

  final argname = getArgs(args);
  var extraStr = "";
  final isdict = value is Map;
  var displayValue = "";

  if (isdict) {
    final mapName = "map";
    final mapEntries = <String>[];
    value.forEach((k, v) {
      mapEntries.add(" '$k' : \"${escapeString(v.toString())}\" ");
    });
    extraStr = 'final $mapName = {\n        ${mapEntries.join(',\n        ')}\n      };\n      ';
    final firstArgParts = args[0].split('@');
    final firstArgName = firstArgParts.length == 2 ? firstArgParts[1] : firstArgParts[0];
    displayValue = "$mapName[$firstArgName] ?? ''";
  } else {
    displayValue = '"${escapeString(value.toString())}"';
  }

  return '''
  @override
  String $name($argname) {
     ${extraStr}return $displayValue;
  }
''';
}

String shiftArg(String name, String key) {
  final pattern = RegExp(r'^([^_]+)(.*)$');
  final match = pattern.firstMatch(name);
  if (match != null) {
    final p1 = match.group(1)!;
    final p2 = match.group(2)!;
    return '${p1}_$key$p2';
  }
  return '${name}_$key';
}

Map<String, dynamic> flattenJson(dynamic y) {
  final out = <String, dynamic>{};
  void flatten(dynamic x, String name) {
    if (x is Map) {
      x.forEach((key, val) {
        flatten(val, name + key.toString());
      });
    } else {
      out[name] = x;
    }
  }
  flatten(y, '');
  return out;
}

class I18nGenerationResult {
  final String helperName;
  final String defaultCls;
  final String defaultObj;
  final String delegate;
  final String l18n;
  final List<String> names;
  final Map<String, List<String>> code;
  final String extra;
  final Map<String, String> locales;
  final Map<String, dynamic> aliases;
  final String defaultLocaleStr;

  I18nGenerationResult({
    required this.helperName,
    required this.defaultCls,
    required this.defaultObj,
    required this.delegate,
    required this.l18n,
    required this.names,
    required this.code,
    required this.extra,
    required this.locales,
    required this.aliases,
    required this.defaultLocaleStr,
  });
}

void _deepMerge(Map target, Map source) {
  for (final key in source.keys) {
    final sourceValue = source[key];
    final targetValue = target[key];
    if (sourceValue is Map) {
      if (targetValue is Map) {
        _deepMerge(targetValue, sourceValue);
      } else {
        final newMap = <String, dynamic>{};
        _deepMerge(newMap, sourceValue);
        target[key] = newMap;
      }
    } else {
      target[key] = sourceValue;
    }
  }
}

I18nGenerationResult runI18nGenerator(String yamlContent, [String? yamlPath]) {
  final yamlMap = loadYaml(yamlContent) as YamlMap;
  final obj = convertYamlMap(yamlMap);

  final settings = obj['settings'] as Map? ?? {};
  final includeSubdir = settings['include']?.toString();
  if (includeSubdir != null && includeSubdir.isNotEmpty) {
    final yamlDir = yamlPath != null && yamlPath.isNotEmpty ? p.dirname(yamlPath) : Directory.current.path;
    final includePath = p.normalize(p.join(yamlDir, includeSubdir));
    final includeDir = Directory(includePath);
    if (includeDir.existsSync()) {
      try {
        final files = includeDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.yaml') || f.path.endsWith('.yml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

        obj['Strings'] ??= <String, dynamic>{};
        final stringsMap = obj['Strings'] as Map;

        for (final file in files) {
          final content = loadContent(file.path);
          if (content != null && content.isNotEmpty) {
            final includedYaml = loadYaml(content);
            if (includedYaml is Map) {
              final includedMap = convertYamlMap(includedYaml as YamlMap);
              _deepMerge(stringsMap, includedMap);
            }
          }
        }
      } catch (e) {
        stderr.writeln("Warning: failed to process include subfolder '$includeSubdir': $e");
      }
    }
  }

  final l18n = settings['l18n']?.toString() ?? 'l18n';
  final helperName = settings['helper']?.toString() ?? 'S';
  final defaultCls = settings['default_class']?.toString() ?? 'TI';
  final defaultObj = settings['default_object']?.toString() ?? 'R';
  final delegate = settings['delegate']?.toString() ?? 'TRLocalizationDelegate';

  final language = obj['Languages'] as List?;
  final stringsRaw = obj['Strings'];
  final shared = obj['Shared'] as Map?;

  if (language == null) {
    error("Missing language definition");
  }

  final result = List.generate(language.length, (_) => <String, dynamic>{});
  final names = <String>[];
  final locales = <String, String>{};
  final aliases = <String, dynamic>{};
  var defaultLocale = '';

  for (final value in language) {
    if (value is! Map) continue;
    final name = value['name']?.toString() ?? '';
    final alias = value['alias'];
    final locale = value['locale']?.toString();
    final isDefault = value['default'] == true;

    names.add(name);
    if (locale != null) {
      locales[name] = locale;
      if (defaultLocale.isEmpty && isDefault) {
        defaultLocale = locale;
      }
      if (alias != null) {
        if (alias is List) {
          for (final a in alias) {
            aliases[a.toString()] = locale;
          }
        } else {
          aliases[alias.toString()] = locale;
        }
      }
    }
  }

  if (defaultLocale.isEmpty && names.isNotEmpty) {
    defaultLocale = locales[names[0]] ?? '';
  }

  final sharedKeys = List.generate(language.length, (_) => <String, String>{});

  String convertShared(String value, int i) {
    return DartTemplate(value, delimiter: r'$@').safeSubstitute(sharedKeys[i]);
  }

  if (shared != null) {
    for (final entry in shared.entries) {
      final sk = entry.key.toString();
      final sv = entry.value;
      List<dynamic> svList;
      if (sv is List) {
        svList = sv;
      } else {
        svList = List.filled(language.length, sv);
      }

      for (var i = 0; i < svList.length; i++) {
        final v = svList[i]?.toString() ?? '';
        final cv = convertShared(v, i);
        sharedKeys[i][sk] = cv;
      }
    }
  }

  if (stringsRaw != null) {
    final nl = names.length;
    final strings = flattenJson(stringsRaw);

    for (final entry in strings.entries) {
      final key = entry.key.replaceAll(RegExp(r'\s'), '');
      var value = entry.value;

      List<dynamic> valueList;
      if (value is List) {
        valueList = List.from(value);
      } else {
        valueList = List.filled(nl, value);
      }

      if (valueList.length < nl) {
        final firstVal = valueList[0];
        for (var j = valueList.length; j < nl; j++) {
          valueList.add(firstVal);
        }
      }

      var needConversion = false;
      var newKey = key;

      for (var i = 0; i < nl; i++) {
        var v = valueList[i];
        if (v is Map) {
          needConversion = true;
          v = jsonEncode(v);
        }
        var sv = v.toString();
        try {
          sv = convertShared(sv, i);
        } catch (e) {
          stderr.writeln("For your key: $key has too many values to pack, expected less than $nl");
          rethrow;
        }

        dynamic finalVal = sv;
        if (needConversion) {
          finalVal = jsonDecode(sv);
          newKey = shiftArg(key, 'key');
        }
        result[i][newKey] = finalVal;
      }
    }

    for (var i = 0; i < nl; i++) {
      for (final entry in sharedKeys[i].entries) {
        result[i]['Shared${entry.key}'] = entry.value;
      }
    }
  }

  final code = <String, List<String>>{};
  final keys = result.isNotEmpty ? (result[0].keys.toList()..sort()) : <String>[];

  for (final k in keys) {
    final parts = k.split('_');
    final first = parts[0];
    final rest = parts.sublist(1).where((p) => p.isNotEmpty).toList();

    code.putIfAbsent(defaultCls, () => []).add(generateInterface(first, rest));

    for (var j = 0; j < names.length; j++) {
      final name = names[j];
      final value = result[j][k];
      code.putIfAbsent(name, () => []).add(generateOverride(first, value, rest));
    }
  }

  return I18nGenerationResult(
    helperName: helperName,
    defaultCls: defaultCls,
    defaultObj: defaultObj,
    delegate: delegate,
    l18n: l18n,
    names: names,
    code: code,
    extra: obj['extra']?.toString() ?? '',
    locales: locales,
    aliases: aliases,
    defaultLocaleStr: defaultLocale,
  );
}


void generateI18nMultiFile(
  String yamlContent,
  String yamlPath,
  String outputDir,
  String helperNameOpt,
  String defaultClsOpt,
  String defaultObjOpt,
  bool interfaceOnly,
  String argsList,
) {
  final gen = runI18nGenerator(yamlContent, yamlPath);

  final helperName = helperNameOpt.isNotEmpty ? helperNameOpt : gen.helperName;
  final defaultCls = defaultClsOpt.isNotEmpty ? defaultClsOpt : gen.defaultCls;
  final defaultObj = defaultObjOpt.isNotEmpty ? defaultObjOpt : gen.defaultObj;

  final notes = "/// generated content don't modify it manually, modify ${p.basename(yamlPath)} instead\n///Via: l18n_gen.py $argsList\n";
  final defaultPkg = "$helperName.dart";

  final defaultTemplate = DartTemplate(notes + '''
part of '%package';
class %interface {
  %code
  static %interface instance() => %interface();
}
''');

  final clsTemplate = DartTemplate(notes + '''
part of '%package';

class %cls extends %interface {
   %code
   static %cls instance() => %cls();
}
''');

  final simpleHelper = notes + '''
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb;
import 'dart:ui' as ui;

%extra

// where the auto generated language implementations
%parts;
''';

  final helper = simpleHelper + '''

class %cls {
 static const map = {
   // locale to instance map
   %code
 };

 // alias map
 static const aliases = %alias;
 // default locale 
 static const defaultLocale = Locale(%defaultLocale);

 static Locale? currentLocale;
  static dynamic supportedLocale(Locale locale){
    final sLocal = locale.toString();
    var cls = map[sLocal];
    if (cls == null ){ 
      if (aliases.containsKey(sLocal)){
        cls = map[aliases[sLocal]];
      }else {
        final short = locale.languageCode;
        cls = map[short];
      }
    }
    return cls;
  }
  static %interface get %default_obj  {
    if (currentLocale == null) {
      String locale = '';
      if (kIsWeb){
        locale = ui.PlatformDispatcher.instance.locale.toLanguageTag();
      }else {
        locale = Platform.localeName;
      }
      final PL = locale.replaceAll(RegExp(r'\\..*\$'), "").replaceAll('-', '_').split('_');
      currentLocale = Locale(PL[0],PL.length > 1 ? PL[1] : null) ;
    }
    final cls = supportedLocale(currentLocale!);
    final found = cls ?? map[defaultLocale.toString()];
    if (found == null){
      throw Exception('Unknown locale \$currentLocale specified');
    }
    return found() as %interface;
  }
}
%interface %default_obj = %cls.%default_obj;

class %delegate extends LocalizationsDelegate<%interface> {
  const %delegate();

  List<Locale> get supportedLocales {
    return %cls.map.keys.map(
        (name) { 
          List<String> code = name.split("_");
          String? cc = code.length > 1 ? code[1] : null;
          return Locale.fromSubtags(languageCode: code[0], countryCode: cc);
        }
    ).toList();
  }
  
  @override
  bool isSupported(Locale locale) => _isSupported(locale);
  @override
  Future<%interface> load(Locale locale) {
    %cls.currentLocale = locale;
   return  Future.value(%cls.%default_obj);
  }
  @override 
  bool shouldReload(${gen.delegate} old) => false;

  bool _isSupported(Locale locale) {
    return %cls.supportedLocale(locale) != null;
  }
} 
extension LExt%l18n on BuildContext {
  %interface get %l18n => %cls.%default_obj;
}

''';

  final interfaceCode = gen.code[defaultCls]?.join('\n') ?? '';
  writeContent(
    p.join(outputDir, "$defaultCls.dart"),
    defaultTemplate.safeSubstitute({
      'package': defaultPkg,
      'interface': defaultCls,
      'code': interfaceCode,
    }),
  );

  if (!interfaceOnly) {
    for (final name in gen.names) {
      final overrideCode = gen.code[name]?.join('\n') ?? '';
      writeContent(
        p.join(outputDir, "$name.dart"),
        clsTemplate.safeSubstitute({
          'package': defaultPkg,
          'interface': defaultCls,
          'cls': name,
          'code': overrideCode,
        }),
      );
    }
  }

  final templateStr = interfaceOnly ? simpleHelper : helper;
  final defaultLocaleParts = gen.defaultLocaleStr.split('_');
  final defaultLocaleArgs = defaultLocaleParts.map((l) => "'$l'").join(',');

  writeContent(
    p.join(outputDir, "$helperName.dart"),
    DartTemplate(templateStr).safeSubstitute({
      'extra': gen.extra,
      'package': defaultPkg,
      'interface': defaultCls,
      'code': gen.names.map((k) => '"${gen.locales[k]}" : $k.instance').join(',\n    '),
      'cls': helperName,
      'default_obj': defaultObj,
      'parts': (gen.names + [defaultCls]).map((n) => "part '$n.dart'").join(";\n"),
      'alias': jsonEncode(gen.aliases),
      'defaultLocale': defaultLocaleArgs,
      'l18n': gen.l18n,
      'delegate': gen.delegate,
    }),
  );
}

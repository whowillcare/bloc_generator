import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:bloc_gen_plus/src/utils.dart';
import 'package:bloc_gen_plus/src/bloc_generator.dart';
import 'package:bloc_gen_plus/src/i18n_generator.dart';

void main(List<String> args) {
  if (args.isEmpty || args[0] == 'shortcut' || args[0].startsWith('-')) {
    final extraArgs = args.isNotEmpty && args[0] == 'shortcut' ? args.sublist(1) : args;
    handleShortcutCommand(extraArgs);
    return;
  }

  final command = args[0];
  if (command == 'bloc') {
    handleBlocCommand(args.sublist(1));
  } else if (command == 'i18n') {
    handleI18nCommand(args.sublist(1));
  } else {
    print("Unknown command: $command");
    printUsage();
    exit(-1);
  }
}

void printUsage() {
  print("Usage:");
  print("  generator [shortcut]                     - Run shortcut mode: scan directories from build.yaml and generate on-demand");
  print("  generator bloc <subcommand> <yaml_file>  - Run Flutter Bloc code generator");
  print("  generator i18n [options]                 - Run i18n localization generator");
}

void handleBlocCommand(List<String> subArgs) {
  if (subArgs.length < 2) {
    print("Usage: generator bloc <subcommand> <yaml_file>");
    print("Subcommands: all, state, event, bloc");
    exit(-1);
  }
  
  final subcommand = subArgs[0];
  final yamlPath = subArgs[1];
  
  final file = File(yamlPath);
  if (!file.existsSync()) {
    error("YAML file not found: $yamlPath");
  }
  
  final content = file.readAsStringSync();
  final yamlDir = p.dirname(p.canonicalize(yamlPath));
  
  final doc = loadYaml(content);
  if (doc is! Map) {
    error("Invalid YAML format");
  }
  
  final data = convertYamlMap(doc as YamlMap);
  final generatorArgs = GeneratorArgs();
  
  if (!data.containsKey('bloc') && !data.containsKey('state')) {
    data['eventOnly'] = true;
  }
  
  if (subcommand == 'all') {
    allGen(generatorArgs, data, yamlDir);
  } else if (subcommand == 'state') {
    final subData = data.containsKey('state') ? data['state'] as Map<String, dynamic>? : data;
    stateGen(generatorArgs, subData, yamlDir);
  } else if (subcommand == 'event') {
    final subData = data.containsKey('event') ? data['event'] as Map<String, dynamic>? : data;
    eventGen(generatorArgs, subData, yamlDir);
  } else if (subcommand == 'bloc') {
    final subData = data.containsKey('bloc') ? data['bloc'] as Map<String, dynamic>? : data;
    blocGen(generatorArgs, subData, yamlDir);
  } else {
    error("Unknown subcommand: $subcommand");
  }
}

void handleI18nCommand(List<String> subArgs) {
  final parser = ArgParser()
    ..addOption('yaml', abbr: 'y', defaultsTo: 'strings.yaml', help: 'Specify a YAML file containing strings')
    ..addOption('output', abbr: 'o', defaultsTo: './', help: 'Specify where to save generated dart files')
    ..addOption('helper', defaultsTo: 'S', help: 'Specify helper class name')
    ..addOption('interface', defaultsTo: 'TI', help: 'Specify interface class name')
    ..addOption('static', defaultsTo: 'R', help: 'Specify static object name')
    ..addFlag('interface_only', abbr: 'I', defaultsTo: false, help: 'Save interface class file only')
    ..addFlag('example', defaultsTo: false, help: 'Show example YAML');
    
  final results = parser.parse(subArgs);
  
  if (results['example'] == true) {
    print(sampleYaml);
    exit(1);
  }
  
  final yamlPath = results['yaml'] as String;
  final outputOption = results['output'] as String;
  
  final file = File(yamlPath);
  if (!file.existsSync()) {
    error("YAML file not found: $yamlPath");
  }
  
  final yamlContent = file.readAsStringSync();
  final yamlDir = p.dirname(p.canonicalize(yamlPath));
  final outputDir = p.canonicalize(p.join(yamlDir, outputOption));
  
  final helperName = results['helper'] as String;
  final defaultCls = results['interface'] as String;
  final defaultObj = results['static'] as String;
  final interfaceOnly = results['interface_only'] as bool;
  
  final argsList = subArgs.join(' ');
  
  generateI18nMultiFile(
    yamlContent,
    yamlPath,
    outputDir,
    helperName,
    defaultCls,
    defaultObj,
    interfaceOnly,
    argsList,
  );
}

const sampleYaml = '''
Languages:
  - locale: en_US
    name: English
    default: true
  - locale: zh_CN
    name: Chinese
Shared:
  AppName: XSleep
  App: XSleep App
  CompanyName: XSleep Inc.
  CompanyLogo: "https://api.secure.xsleep.com/html/img/cover.png"
  CompanyLogoImgTag: "<img src='\\\$@CompanyLogo' width='100%%' />"
  DiaryNoTitle:
    - No title
    - 无题

Strings:
  HourMeasure:
    - Hours
    - 小时
  MinuteMeasure:
    - Minutes
    - 分钟

  Sleep:
    Set:
      Hours:
        toMuch:
          - "%s %s of sleep might be too much, did you want to make adjustment?"
          - "%s%s的睡眠时间是不是有点夸张了？"
        toLess:
          - "%s %s of sleep might be too less, did you want to make adjustment?"
          - "%s%s的睡眠时间是不是有点不够把？"
    Analysis:
      Color:
        - NotEnough: "#F08080"
          JustRight: "#5d8aa8"
          TooMuch: "#FF8C00"
          Incomplete: "#DC143C"
      Desc:
        - NotEnough: You don't seem to have enough sleep!
          JustRight: You must have got a very good dream, mind to share?
          TooMuch: "You seem to have overslept!"
          Incomplete: You might have forgot to end your sleep?
        - NotEnough: 你好象睡得太少了呀！
          JustRight: 你肯定作了个很好的梦，记得和大家分享哦？
          TooMuch: 你可能睡过头了？
          Incomplete: 你可能忘了打卡？
''';

RegExp globToRegex(String glob) {
  var regexStr = glob
      .replaceAll('.', r'\.')
      .replaceAll('**', '__DOUBLE_STAR__')
      .replaceAll('*', '__SINGLE_STAR__')
      .replaceAll('__DOUBLE_STAR__', '.*')
      .replaceAll('__SINGLE_STAR__', '[^/]*');
  return RegExp('^$regexStr\$');
}



void handleShortcutCommand([List<String> extraArgs = const []]) {
  List<String> blocGlobs = [];
  List<String> i18nGlobs = [];
  
  final buildYamlFile = File('build.yaml');
  if (buildYamlFile.existsSync()) {
    try {
      final doc = loadYaml(buildYamlFile.readAsStringSync());
      if (doc is Map && doc.containsKey('targets')) {
        final targets = doc['targets'];
        if (targets is Map) {
          for (final targetKey in targets.keys) {
            final target = targets[targetKey];
            if (target is Map && target.containsKey('builders')) {
              final builders = target['builders'];
              if (builders is Map) {
                for (final builderKey in builders.keys) {
                  final builder = builders[builderKey];
                  if (builder is Map && builder.containsKey('generate_for')) {
                    final generateFor = builder['generate_for'];
                    final globs = (generateFor as List).map((g) => g.toString()).toList();
                    if (builderKey.toString().endsWith('bloc_builder')) {
                      blocGlobs.addAll(globs);
                    } else if (builderKey.toString().endsWith('i18n_builder')) {
                      i18nGlobs.addAll(globs);
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print("Warning: Failed to parse build.yaml: $e");
    }
  }

  if (blocGlobs.isEmpty) {
    blocGlobs = ['**/*.bloc.yaml'];
  }
  if (i18nGlobs.isEmpty) {
    i18nGlobs = ['**/*.i18n.yaml'];
  }

  print("Shortcut scan config:");
  print("  Bloc globs: $blocGlobs");
  print("  i18n globs: $i18nGlobs");

  final List<File> allFiles = [];
  void collectFiles(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = p.basename(entity.path);
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        if (name == 'node_modules' || name == 'build') continue;
        collectFiles(entity);
      } else if (entity is File) {
        allFiles.add(entity);
      }
    }
  }
  
  if (Directory('lib').existsSync()) {
    collectFiles(Directory('lib'));
  } else {
    collectFiles(Directory.current);
  }

  final List<String> relativePaths = allFiles
      .map((f) => p.relative(f.path, from: Directory.current.path))
      .toList();

  final List<String> blocFiles = [];
  final List<String> i18nFiles = [];

  for (final path in relativePaths) {
    for (final glob in blocGlobs) {
      if (globToRegex(glob).hasMatch(path) && path.endsWith('.yaml')) {
        blocFiles.add(path);
        break;
      }
    }
    for (final glob in i18nGlobs) {
      if (globToRegex(glob).hasMatch(path) && path.endsWith('.yaml')) {
        i18nFiles.add(path);
        break;
      }
    }
  }

  print("Found ${blocFiles.length} Bloc config files and ${i18nFiles.length} i18n config files.");

  for (final blocPath in blocFiles) {
    if (shouldBuild(blocPath)) {
      print("Generating Bloc from $blocPath...");
      final file = File(blocPath);
      final content = file.readAsStringSync();
      final doc = loadYaml(content);
      if (doc is Map) {
        final data = convertYamlMap(doc as YamlMap);
        final yamlDir = p.dirname(p.canonicalize(blocPath));
        final generatorArgs = GeneratorArgs();
        if (!data.containsKey('bloc') && !data.containsKey('state')) {
          data['eventOnly'] = true;
        }
        allGen(generatorArgs, data, yamlDir);
        writeMark(blocPath);
      } else {
        print("Error: Invalid YAML format in $blocPath");
      }
    }
  }

  for (final i18nPath in i18nFiles) {
    if (shouldBuild(i18nPath)) {
      print("Generating i18n from $i18nPath...");
      final file = File(i18nPath);
      final content = file.readAsStringSync();
      final yamlDir = p.dirname(p.canonicalize(i18nPath));
      generateI18nMultiFile(
        content,
        i18nPath,
        yamlDir,
        'S',
        'TI',
        'R',
        false,
        '',
      );
      writeMark(i18nPath);
    }
  }

  print("Running build_runner runner...");
  final result = Process.runSync(
    'dart',
    ['run', 'build_runner', 'build', '--delete-conflicting-outputs', ...extraArgs],
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    exit(result.exitCode);
  }
}


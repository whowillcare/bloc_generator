import 'dart:io';
import 'package:path/path.dart' as p;
import 'utils.dart';

class Vars {
  final String origin;
  late final String clsname;
  late final String cls;
  late final String optional;
  late final String name;
  late final String value;
  late final String jsonKey;
  late final String comment;

  Vars(this.origin) {
    final pattern = RegExp(r'^(?:(([\w<,>]+)(\??))\s+)(\w+)([\s\S]*)?$');
    final lesser = RegExp(r'^(\w+)([\s\S]*)$');
    
    var tempClsname = 'String';
    var tempCls = 'String';
    var tempOptional = '';
    var tempName = '';
    var tempValue = '';

    final match = pattern.firstMatch(origin.trim());
    if (match != null) {
      tempClsname = match.group(1) ?? 'String';
      tempCls = match.group(2) ?? 'String';
      tempOptional = match.group(3) ?? '';
      tempName = match.group(4) ?? '';
      tempValue = match.group(5) ?? '';
    } else {
      final shortMatch = lesser.firstMatch(origin.trim());
      if (shortMatch != null) {
        tempName = shortMatch.group(1) ?? '';
        tempValue = shortMatch.group(2) ?? '';
      }
    }

    var commentStr = '';
    var jkStr = '';

    if (tempValue.isNotEmpty) {
      final commRegExp = RegExp(r'(//.*$)');
      final commMatch = commRegExp.firstMatch(tempValue);
      if (commMatch != null) {
        commentStr = commMatch.group(1) ?? '';
        tempValue = tempValue.replaceAll(commRegExp, '');
        
        final jkRegExp = RegExp(r'\(jk@\s*(.*?)\)');
        final jkMatch = jkRegExp.firstMatch(commentStr);
        if (jkMatch != null) {
          commentStr = commentStr.replaceAll(jkRegExp, '');
          jkStr = jkMatch.group(1) ?? '';
        }
      }
    }

    clsname = tempClsname;
    cls = tempCls;
    optional = tempOptional;
    name = tempName;
    value = tempValue.trim();
    jsonKey = jkStr;
    comment = commentStr;
  }
}

class GeneratorArgs {
  String name;
  String path;
  String dest;
  String part;
  bool overwrite;
  bool init;
  String jsonConverter;
  List<String> props;
  bool equal;
  String parent;
  bool useJson;
  String eventFile;
  String stateFile;
  String repoFile;
  bool useHydrate;
  bool useReplay;
  dynamic events; // List or Map

  GeneratorArgs({
    this.name = '',
    this.path = '',
    this.dest = '',
    this.part = '',
    this.overwrite = true,
    this.init = false,
    this.jsonConverter = '',
    this.props = const [],
    this.equal = true,
    this.parent = '',
    this.useJson = true,
    this.eventFile = '',
    this.stateFile = '',
    this.repoFile = '',
    this.useHydrate = true,
    this.useReplay = false,
    this.events = const [],
  });
}



dynamic getClass(String? content, {bool first = true}) {
  if (content == null || content.isEmpty) return null;
  final regex = RegExp(r'\bclass\s+(\w+)');
  final matches = regex.allMatches(content);
  final result = matches.map((m) => m.group(1)!).toList();
  if (result.isEmpty) return null;
  if (first) return result.first;
  return result;
}

void syncData(GeneratorArgs args, Map<String, dynamic> fields, Map<String, dynamic>? data, String yamlDir) {
  final d = data ?? {};
  
  args.name = args.name.isNotEmpty ? args.name : (d['name']?.toString() ?? fields['name']?.toString() ?? '');
  args.path = args.path.isNotEmpty ? args.path : (d['path']?.toString() ?? fields['path']?.toString() ?? '');
  args.dest = args.dest.isNotEmpty ? args.dest : (d['dest']?.toString() ?? fields['dest']?.toString() ?? '');
  args.part = args.part.isNotEmpty ? args.part : (d['part']?.toString() ?? fields['part']?.toString() ?? '');
  args.overwrite = d.containsKey('overwrite') ? (d['overwrite'] == true) : (fields['overwrite'] == true);
  
  if (fields.containsKey('init')) {
    args.init = d.containsKey('init') ? (d['init'] == true) : (fields['init'] == true);
  }
  if (fields.containsKey('jsonConverter')) {
    args.jsonConverter = d['jsonConverter']?.toString() ?? fields['jsonConverter']?.toString() ?? '';
  }
  if (fields.containsKey('props')) {
    if (d.containsKey('props')) {
      args.props = (d['props'] as List).map((p) => p.toString()).toList();
    } else {
      args.props = (fields['props'] as List).map((p) => p.toString()).toList();
    }
  }
  if (fields.containsKey('equal')) {
    args.equal = d.containsKey('equal') ? (d['equal'] == true) : (fields['equal'] == true);
  }
  if (fields.containsKey('parent')) {
    args.parent = d['parent']?.toString() ?? fields['parent']?.toString() ?? '';
  }
  if (fields.containsKey('useJson')) {
    args.useJson = d.containsKey('useJson') ? (d['useJson'] == true) : (fields['useJson'] == true);
  }
  if (fields.containsKey('event_file')) {
    args.eventFile = d['event_file']?.toString() ?? fields['event_file']?.toString() ?? '';
  }
  if (fields.containsKey('state_file')) {
    args.stateFile = d['state_file']?.toString() ?? fields['state_file']?.toString() ?? '';
  }
  if (fields.containsKey('repo_file')) {
    args.repoFile = d['repo_file']?.toString() ?? fields['repo_file']?.toString() ?? '';
  }
  if (fields.containsKey('useHydrate')) {
    args.useHydrate = d.containsKey('useHydrate') ? (d['useHydrate'] == true) : (fields['useHydrate'] == true);
  }
  if (fields.containsKey('useReplay')) {
    args.useReplay = d.containsKey('useReplay') ? (d['useReplay'] == true) : (fields['useReplay'] == true);
  }
  if (fields.containsKey('events')) {
    args.events = d['events'] ?? fields['events'] ?? [];
  }

  if (args.dest.isNotEmpty && args.dest.startsWith('.')) {
    if (args.part.isNotEmpty) {
      final partName = p.basenameWithoutExtension(args.part);
      args.dest = partName + args.dest;
    }
  }
  
  if (args.dest.isNotEmpty) {
    args.dest = p.canonicalize(p.join(yamlDir, args.path, args.dest));
  }
}

String stateGen(GeneratorArgs args, Map<String, dynamic>? data, String yamlDir) {
  final fields = {
    'equal': true,
    'parent': '',
    'init': false,
    'name': 'DemoState',
    'jsonConverter': '',
    'extraKeys': [],
    'props': [],
    'include': r'^.*$',
    'useJson': true,
    'dest': null,
    'part': "",
    'overwrite': true,
  };
  
  syncData(args, fields, data, yamlDir);

  if (args.name.isEmpty) {
    error("Missing class name");
  }
  if (args.props.isEmpty) {
    error("We need some properties");
  }

  var parentClass = '';
  var parentClassExtends = args.equal ? 'Equatable' : '';
  final vars = args.props.map((p) => Vars(p)).toList();

  final finalLines = <String>[];
  final constParams = <String>[];
  final copyWithArgs = <String>[];
  final copyWithBody = <String>[];
  final props = <String>[];

  final extraKeys = data != null ? (data['extraKeys'] as List?)?.map((k) => k.toString()).toList() ?? [] : [];

  var fact = args.useJson
      ? '    factory %clsname.fromJson(Map<String,dynamic> json)=>_\$%clsnameFromJson(json);  \n    \n    Map<String, dynamic> toJson() => _\$%clsnameToJson(this);\n'
          .replaceAll('%clsname', args.name)
      : '';
  
  if (args.useJson && extraKeys.isNotEmpty) {
    final addAllStr = '\n..addAll({\n      ${extraKeys.map((b) => "'$b':$b").join(',\n      ')}\n    })';
    fact = fact.replaceAll(RegExp(r';\s*$'), '$addAllStr;\n');
  }

  final initMethod = args.init
      ? '  static %clsname init() {\n    return const %clsname();\n  }'.replaceAll('%clsname', args.name)
      : '';

  for (final v in vars) {
    finalLines.add('${v.comment}${v.jsonKey.isNotEmpty ? "\n  @JsonKey(name: '${v.jsonKey}')" : ""}\n  final ${v.clsname} ${v.name}');
    
    final isRequired = v.value.isEmpty && v.optional.isEmpty;
    constParams.add('${isRequired ? "required " : ""}this.${v.name}${v.value.isNotEmpty ? " ${v.value}" : ""}');
    
    copyWithArgs.add('${v.cls}? ${v.name}');
    copyWithBody.add('${v.name}: ${v.name} ?? this.${v.name}');
    
    if (args.equal) {
      final toAppend = v.name;
      final includePattern = data != null && data['include'] != null ? RegExp(data['include'].toString()) : RegExp('^.*\$');
      final excludePattern = data != null && data['exclude'] != null ? RegExp(data['exclude'].toString()) : null;
      if (!includePattern.hasMatch(toAppend)) continue;
      if (excludePattern != null && excludePattern.hasMatch(toAppend)) continue;
      props.add(toAppend);
    }
  }

  if (args.parent.isNotEmpty) {
    final realParentFile = p.canonicalize(p.join(yamlDir, args.path, args.parent));
    final parentContent = loadContent(realParentFile);
    if (parentContent != null) {
      final parentResult = getClass(parentContent, first: true) as String?;
      if (parentResult != null) {
        parentClass = parentResult;
        args.equal = true;
        parentClassExtends = parentClass;
        
        final keysPattern = RegExp(r'final\s+(\S*?)(\?){0,1}\s+(\S+);');
        final matches = keysPattern.allMatches(parentContent);
        for (final match in matches) {
          final keyType = match.group(1) ?? '';
          final optional = match.group(2) ?? '';
          final key = match.group(3) ?? '';
          
          constParams.add('${optional.isEmpty ? "required " : ""}super.$key');
          copyWithArgs.add('$keyType? $key');
          copyWithBody.add('$key: $key ?? this.$key');
        }
        props.add('...super.props');
      }
    } else {
      error("${args.parent} specified but not existent or no content");
    }
  }

  final ext = parentClassExtends.isNotEmpty ? 'extends $parentClassExtends' : '';
  final ret = DartTemplate('''
%part
%serial
%converter
class %clsname %ext {
  %final;

  const %clsname({%const});

  %init

  %clsname copyWith({%copyWithArgs}){
    return %clsname(
      %copyWithBody
    );
  }

  %fact

  %props
}
''').safeSubstitute({
    'serial': args.useJson ? '@JsonSerializable(explicitToJson: true)' : '',
    'clsname': args.name,
    'final': finalLines.join(';\n  '),
    'const': constParams.join(', '),
    'copyWithArgs': copyWithArgs.join(', '),
    'copyWithBody': copyWithBody.join(',\n      '),
    'props': args.equal ? '@override\n  List<Object?> get props => [\n    ${props.join(',\n    ')}\n  ];\n' : '',
    'ext': ext,
    'fact': fact,
    'part': args.part.isNotEmpty ? "part of '${args.part}';\n" : '',
    'init': initMethod,
    'converter': args.jsonConverter.isNotEmpty ? '@${args.jsonConverter}()' : '',
  });

  if (args.dest.isNotEmpty) {
    writeContent(args.dest, ret, overwrite: args.overwrite);
  }
  return ret;
}

Map<String, List<dynamic>> EVENT_SHORTCUT = {};

String eventGen(GeneratorArgs args, Map<String, dynamic>? data, String yamlDir) {
  final fields = {
    'name': 'BaseEvent',
    'useReplay': false,
    'events': [],
    'dest': null,
    'part': "",
    'overwrite': true,
  };

  syncData(args, fields, data, yamlDir);

  final vs = <String, List<Vars>>{};
  final events = args.events;
  const DELI = '#';
  var replayEvent = args.useReplay ? ' implements ReplayEvent' : '';

  Vars convertToVar(String inp) {
    return Vars(inp);
  }

  if (events is Map) {
    events.forEach((k, vv) {
      final key = k.toString();
      if (vv == null) {
        vs[key] = [];
      } else if (vv is List) {
        vs[key] = vv.map((v) => convertToVar(v.toString())).toList();
      }
    });
  } else if (events is List) {
    for (final v in events) {
      final vStr = v.toString();
      final parts = vStr.split(DELI);
      var eventname = '';
      var val = vStr;
      if (parts.length == 2) {
        eventname = parts[0];
        val = parts[1];
      }
      vs.putIfAbsent(eventname, () => []).add(convertToVar(val));
    }
  }

  final basename = args.name;
  var ret = "sealed class $basename$replayEvent {}\n\n";

  const eventTemplate = '''class %event_name extends %base_name {
    %extra
}    
''';

  vs.forEach((enOrig, eps) {
    var en = enOrig;
    var shortcut = "";
    if (en.contains('~')) {
      final pattern = RegExp(r'^(.+)~(.*)$');
      final match = pattern.firstMatch(en);
      if (match != null) {
        en = match.group(1)!;
        shortcut = match.group(2)!;
      }
    }
    if (en.startsWith('.')) {
      en = basename + en.substring(1);
    } else if (en.startsWith('%')) {
      en = en.substring(1) + basename;
    }

    final sargs = <List<String>>[[], []];
    if (shortcut.isNotEmpty) {
      EVENT_SHORTCUT[en] = [shortcut, sargs];
    }

    var extra = "";
    final finalLines = <String>[];
    final constParams = <String>[];

    if (eps.isNotEmpty) {
      for (final v in eps) {
        if (shortcut.isNotEmpty) {
          final isRequired = v.value.isEmpty && v.optional.isEmpty;
          sargs[0].add('${isRequired ? "required " : ""}${v.clsname} ${v.name}${v.value.isNotEmpty ? " ${v.value}" : ""}');
          sargs[1].add('${v.name}: ${v.name}');
        }
        finalLines.add('${v.comment}\n  final ${v.clsname} ${v.name}');
        constParams.add('${v.value.isEmpty && v.optional.isEmpty ? "required " : ""}this.${v.name}${v.value.isNotEmpty ? " ${v.value}" : ""}');
      }

      extra = DartTemplate('''
  %final;
  %clsname({%const});
''').safeSubstitute({
        'clsname': en,
        'final': finalLines.join(';\n  '),
        'const': constParams.join(', '),
      });
    }

    ret += DartTemplate(eventTemplate).safeSubstitute({
      'base_name': basename,
      'event_name': en,
      'extra': extra,
    });
  });

  if (args.part.isNotEmpty) {
    ret = "part of '${args.part}';\n\n$ret";
  }

  if (args.dest.isNotEmpty) {
    writeContent(args.dest, ret, overwrite: args.overwrite);
  }
  return ret;
}

String blocGen(GeneratorArgs args, Map<String, dynamic>? data, String yamlDir) {
  final fields = {
    'name': 'BaseBloc',
    'useHydrate': true,
    'state_file': null,
    'event_file': null,
    'repo_file': null,
    'useReplay': false,
    'dest': null,
    'part': "",
    'overwrite': true,
  };

  syncData(args, fields, data, yamlDir);

  if (args.stateFile.isEmpty) {
    error("Missing state file");
  }
  if (args.eventFile.isEmpty) {
    error("Missing event file");
  }

  final stateFile = p.canonicalize(p.join(yamlDir, args.path, args.stateFile));
  final eventFile = p.canonicalize(p.join(yamlDir, args.path, args.eventFile));
  final repoFile = args.repoFile.isNotEmpty ? p.canonicalize(p.join(yamlDir, args.path, args.repoFile)) : '';

  final stateContent = loadContent(stateFile);
  final eventContent = loadContent(eventFile);
  final repoContent = repoFile.isNotEmpty ? loadContent(repoFile) : null;

  if (repoFile.isNotEmpty && repoContent == null) {
    error("${args.repoFile} doesn't seem to exist");
  }

  final existContent = args.dest.isNotEmpty ? loadContent(args.dest) : null;
  final replayMixins = args.useReplay ? ' with ReplayBlocMixin' : '';

  List<String> eventHandlers(String eventName, String state) {
    const comma = ", ";
    final func = '_on$eventName';
    var short = "";
    final argsShortcut = EVENT_SHORTCUT[eventName];
    if (argsShortcut != null) {
      final name = argsShortcut[0] as String;
      final rest = argsShortcut[1] as List<List<String>>;
      var argdef = "";
      var arg = "";
      if (rest.length == 2 && rest[0].isNotEmpty) {
        argdef = rest[0].join(comma);
        arg = rest[1].join(comma);
      }
      short = DartTemplate('''
    void %name(%argdef){
      add(%event(%arg));
    }''').safeSubstitute({
        'name': name,
        'argdef': argdef.isNotEmpty ? '{$argdef}' : '',
        'event': eventName,
        'arg': arg,
      });
    }

    return [
      'on<$eventName>($func)',
      '  Future<void> $func($eventName event, Emitter<$state> emit) async {\n    //TODO add your code here\n  }\n',
      short
    ];
  }

  const blocTemplate = '''
%part
class %bloc_class extends %{mixins}Bloc<%event_class, %state_class>%replay_mixins {
   %repo
   %constructor
   %hydrate
   %shortcut
%event_handler
}
''';

  const shortcutMark = "/// shortcut functions";
  const shortcutMarkEnd = "/// end shortcut";

  String addMark(String content) {
    return "$shortcutMark\n$content\n   $shortcutMarkEnd\n";
  }

  if (eventContent == null || eventContent.isEmpty) {
    error("Wrong content from $eventFile");
  }

  final eventClassesListRaw = getClass(eventContent, first: false) as List<dynamic>?;
  if (eventClassesListRaw == null || eventClassesListRaw.isEmpty) {
    error("Missing classes in event content");
  }
  final eventClassesList = eventClassesListRaw.map((e) => e.toString()).toList();
  final eventBase = eventClassesList.first;
  final eventClasses = eventClassesList.sublist(1);

  var repoClass = "";
  if (repoContent != null) {
    final rc = getClass(repoContent);
    if (rc == null) {
      error("$repoFile is not a valid dart class file?!");
    }
    repoClass = rc.toString();
  }

  final stateClassRaw = getClass(stateContent) as String?;
  if (stateClassRaw == null) {
    error("Missing right content from $stateFile");
  }
  final stateClass = stateClassRaw;

  var ret = "";

  List<String> getHandlerFunc(List<String> events) {
    final eventFuncs = <String>[];
    final eventHandler = <String>[];
    final eventShort = <String>[];
    for (final event in events) {
      final eh = eventHandlers(event, stateClass);
      eventHandler.add(eh[0]);
      eventFuncs.add(eh[1]);
      if (eh[2].isNotEmpty) {
        eventShort.add(eh[2]);
      }
    }
    return [
      eventFuncs.join('\n') + '\n',
      eventHandler.join(';\n      ') + ';\n      ',
      eventShort.join('\n') + '\n',
    ];
  }

  if (existContent != null && existContent.isNotEmpty) {
    final constructHandlerPattern = RegExp(r'on<(\w+)>\(_on\w+\)');
    final existEvents = constructHandlerPattern.allMatches(existContent).map((m) => m.group(1)!).toList();
    
    final eventHandlerPattern = RegExp(r' _on(\w+)\(');
    final existEventFuncs = eventHandlerPattern.allMatches(existContent).map((m) => m.group(1)!).toList();

    if (existEvents.isNotEmpty && existEventFuncs.isNotEmpty) {
      ret = existContent;
      final missedEvents = eventClasses.where((e) => !existEvents.contains(e)).toList();
      if (missedEvents.isNotEmpty) {
        final handlerFuncs = getHandlerFunc(missedEvents);
        final eventFuncsStr = handlerFuncs[0];
        final eventHandlerStr = handlerFuncs[1];
        final shortStr = handlerFuncs[2];

        if (eventHandlerStr.trim().isNotEmpty) {
          ret = ret.replaceAllMapped(RegExp(r'(super.*?{)'), (match) {
            return '${match.group(1)}\n      ${eventHandlerStr.trim()}';
          });
        }
        if (eventFuncsStr.trim().isNotEmpty) {
          ret = ret.replaceAllMapped(RegExp(r'(}\s*)$'), (match) {
            return '$eventFuncsStr${match.group(1)}';
          });
        }
        if (shortStr.trim().isNotEmpty) {
          final hasmark = ret.contains(shortcutMark);
          final shortPattern = hasmark 
              ? RegExp('$shortcutMark\n') 
              : RegExp(r'(super.*?\{[^}]+\}([\s\S]*toJson\(\);)?)');
          
          ret = ret.replaceAllMapped(shortPattern, (match) {
            return hasmark 
                ? '${match.group(0)}$shortStr' 
                : '${match.group(1)}\n\n    ${addMark(shortStr)}';
          });
        }
      }
    }
  }

  if (ret.isEmpty) {
    var repoVar = "";
    var repoDef = "";
    if (repoClass.isNotEmpty) {
      repoVar = repoClass[0].toLowerCase() + repoClass.substring(1);
      repoDef = '$repoClass $repoVar;';
      repoVar = '{required this.$repoVar}';
    }
    final handlerFuncs = getHandlerFunc(eventClasses);
    final eventFuncsStr = handlerFuncs[0];
    final eventHandlerStr = handlerFuncs[1];
    var shortcut = handlerFuncs[2];
    if (shortcut.trim().isNotEmpty) {
      shortcut = addMark(shortcut);
    }
    
    final constructor = DartTemplate('''
    %bloc_class(%repo_var) : super(const %state_class()) {
      %event_handlers
    }
''').safeSubstitute({
      'bloc_class': args.name,
      'state_class': stateClass,
      'event_handlers': eventHandlerStr,
      'repo_var': repoVar,
    });

    ret = DartTemplate(blocTemplate).safeSubstitute({
      'bloc_class': args.name,
      'state_class': stateClass,
      'constructor': constructor,
      'event_class': eventBase,
      'shortcut': shortcut,
      'repo': repoDef,
      'event_handler': eventFuncsStr,
      'part': args.part.isNotEmpty ? "part of '${args.part}';\n" : '',
      'mixins': args.useHydrate ? "Hydrated" : "",
      'replay_mixins': replayMixins,
      'hydrate': args.useHydrate ? DartTemplate("""
   @override
   %state_class? fromJson(Map<String, dynamic> json)=>%state_class.fromJson(json);

   @override
   Map<String, dynamic>? toJson(%state_class state)=>state.toJson();
""").safeSubstitute({'state_class': stateClass}) : "",
    });
  }

  if (args.dest.isNotEmpty) {
    writeContent(args.dest, ret, overwrite: args.overwrite);
  }
  return ret;
}

String getCodeStr(Map<String, dynamic> data, String fullname) {
  var code = data['code']?.toString() ?? '';
  final partcode = data['partcode'];
  if (code.isEmpty && partcode != null && partcode != false) {
    final name = p.basename(fullname);
    final partName = p.basenameWithoutExtension(name);
    final partfile = '$partName.c.dart';
    code = "part '$partfile';";
    final partwhere = p.join(p.dirname(fullname), partfile);
    if (!fileExists(partwhere)) {
      writeContent(partwhere, "part of '$partName.dart';\n");
    }
  }
  return code;
}

String allGen(GeneratorArgs args, Map<String, dynamic>? dataRaw, String yamlDir) {
  EVENT_SHORTCUT.clear();
  final data = dataRaw ?? {};
  var processors = ['state', 'event', 'bloc'];
  final prefix = data['prefix']?.toString() ?? '';
  final part = data['part']?.toString() ?? '';
  
  if (part.isEmpty) {
    error("part is mandatory argument in your YAML file");
  }

  String getFullname(String dest, {String mypart = ''}) {
    return p.canonicalize(p.join(p.dirname(dest), mypart.isNotEmpty ? mypart : part));
  }

  String getRel(String where, String fullName) {
    return p.relative(where, from: p.dirname(fullName));
  }

  final path = data['path']?.toString() ?? '';
  var importcode = data['import']?.toString() ?? '';
  final prepare = <String, GeneratorArgs>{};
  final result = <String, String>{};
  final stateOnly = data['stateOnly'] == true;
  var eventOnly = data['eventOnly'] == true;
  if (!data.containsKey('bloc') && !data.containsKey('state')) {
    eventOnly = true;
  }

  if (eventOnly) {
    processors = ['event'];
  }
  
  final useReplay = data['bloc'] is Map ? (data['bloc']['useReplay'] == true) : false;
  if (useReplay) {
    if (data['event'] is Map) {
      data['event']['useReplay'] = useReplay;
    }
  }

  final stateData = data['state'] as Map?;
  final useHydrate = data['bloc'] is Map ? (data['bloc']['useHydrate'] == true) : false;
  final useJson = stateData != null ? (stateData['useJson'] != false) : true;
  final needPart = useJson || useHydrate;

  if (stateData != null) {
    if (stateData.containsKey('parent')) {
      final parentFile = stateData['parent']?.toString() ?? '';
      final dest = stateData['dest']?.toString() ?? (data['bloc'] is Map ? data['bloc']['dest']?.toString() ?? '' : '');
      final fullname = getFullname(p.join(yamlDir, path, dest));
      final realFile = getFullname(fullname, mypart: parentFile);
      if (fileExists(realFile)) {
        stateData['parent'] = realFile;
      } else {
        error("parent specified, but $parentFile's content is not there");
      }
      importcode = "import '$parentFile';\n$importcode";
    }
    
    var equal = true;
    if (stateData.containsKey('equal')) {
      equal = stateData['equal'] == true;
    }
    if (equal) {
      importcode = "import 'package:equatable/equatable.dart';\n$importcode";
    }
  }

  for (final processor in processors) {
    final subdataRaw = data[processor];
    if (subdataRaw == null) {
      if (stateOnly) {
        break;
      } else {
        error("Missing $processor info");
      }
    }
    final subdata = Map<String, dynamic>.from(subdataRaw as Map);
    subdata['path'] = subdata['path']?.toString() ?? path;
    subdata['part'] = subdata['part']?.toString() ?? part;
    if (prefix.isNotEmpty) {
      final capitalized = processor[0].toUpperCase() + processor.substring(1);
      subdata['name'] = '$prefix${subdata['name'] ?? capitalized}';
    }

    final pArgs = GeneratorArgs();
    prepare[processor] = pArgs;

    if (processor == 'bloc') {
      subdata['state_file'] = subdata['state_file']?.toString() ?? prepare['state']?.dest ?? '';
      subdata['event_file'] = subdata['event_file']?.toString() ?? prepare['event']?.dest ?? '';
    }

    if (processor == 'state') {
      result[processor] = stateGen(pArgs, subdata, yamlDir);
    } else if (processor == 'event') {
      result[processor] = eventGen(pArgs, subdata, yamlDir);
    } else if (processor == 'bloc') {
      result[processor] = blocGen(pArgs, subdata, yamlDir);
    }
  }

  if (stateOnly || eventOnly) {
    final key = stateOnly ? 'state' : 'event';
    final ret = result[key]!;
    final pArgs = prepare[key]!;
    if (part.isNotEmpty) {
      final fullname = getFullname(pArgs.dest);
      if (!fileExists(fullname)) {
        final name = p.basename(fullname);
        final partName = p.basenameWithoutExtension(name);
        final partG = needPart ? "part '$partName.g.dart';" : '';
        final codeStr = getCodeStr(data, fullname);
        final statename = getRel(pArgs.dest, fullname);
        
        final template = stateOnly
            ? '''
%extra_import

import 'package:json_annotation/json_annotation.dart';

%part_g
part '%state';

%code
'''
            : '''
%extra_import
part '%state';

%code
''';
        writeContent(fullname, DartTemplate(template).safeSubstitute({
          'extra_import': importcode,
          'part_g': partG,
          'part': partName,
          'state': statename,
          'code': codeStr,
        }));
      }
    }
    return ret;
  }

  final blocArgs = prepare['bloc']!;
  final ret = result['bloc']!;
  if (blocArgs.part.isNotEmpty) {
    final fullname = getFullname(blocArgs.dest, mypart: blocArgs.part);
    final blocname = getRel(blocArgs.dest, fullname);
    final statename = getRel(prepare['state']!.dest, fullname);
    final eventname = getRel(prepare['event']!.dest, fullname);
    final repoFile = prepare['bloc']!.repoFile;

    if (!fileExists(fullname)) {
      final name = p.basename(fullname);
      final partName = p.basenameWithoutExtension(name);
      final partG = needPart ? "part '$partName.g.dart';" : '';
      final codeStr = getCodeStr(data, fullname);
      final blocImport = (prepare['bloc']?.useHydrate == true)
          ? 'package:hydrated_bloc/hydrated_bloc.dart'
          : 'package:flutter_bloc/flutter_bloc.dart';
      
      var extraImportWithReplay = importcode;
      if (prepare['bloc']?.useReplay == true) {
        extraImportWithReplay += "\nimport 'package:replay_bloc/replay_bloc.dart';";
      }

      writeContent(fullname, DartTemplate('''
%extra_import

import '%bloc_import';
import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

%repo_file

%part_g
part '%state';
part '%event';
part '%bloc';

%code
''').safeSubstitute({
        'extra_import': extraImportWithReplay,
        'repo_file': repoFile.isNotEmpty ? "import '${getRel(repoFile, fullname)}';" : "",
        'part_g': partG,
        'part': partName,
        'state': statename,
        'event': eventname,
        'bloc': blocname,
        'code': codeStr,
        'bloc_import': blocImport,
      }));
    }
  }

  return ret;
}

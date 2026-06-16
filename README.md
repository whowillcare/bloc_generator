# bloc_generator

A modern, fast, and fully automated Dart/Flutter package for generating **Bloc classes** (State, Event, Bloc) and **i18n translation/localization files** directly from simple YAML configuration files.

It supports both a **Command Line Interface (CLI)** for direct code generation and integration with the standard Dart **`build_runner` (Builder)** system for seamless compile-time automation.

---

## Features

- 📦 **Automated Bloc Generation**: Generate robust Bloc files (`.dart`, `.s.dart`, `.e.dart`, `.b.dart`) from a single `.bloc.yaml` definition.
- 🌐 **i18n Localization Generation**: Compile translation sheets (`.i18n.yaml`) into strongly-typed localizations helpers (`.i18n.dart`).
- 🔄 **Build Runner Compatibility**: Runs seamlessly alongside packages like `json_serializable` and `equatable`.
- 🛠️ **CLI Support**: Generate code on demand with customized CLI subcommands.

---

## Installation & Setup

Add `bloc_generator` and its peer dependencies to your Dart or Flutter project:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.3
  equatable: ^2.0.5
  json_annotation: ^4.8.1

dev_dependencies:
  build_runner: ^2.4.6
  json_serializable: ^6.7.1
  bloc_generator:
    path: ./ # Or git/pub reference
```

---

## Usage Mode 1: Dart Build Runner (Recommended)

To leverage the Dart build framework for automated compile-time generation:

1. Create a `.bloc.yaml` file in the folder where you want your Bloc code to be generated (e.g. `lib/bloc/my_bloc.bloc.yaml`).
2. Create a `.i18n.yaml` file for translation keys (e.g. `lib/l10n/strings.i18n.yaml`).
3. Run the standard build command:

```bash
dart run build_runner build --delete-conflicting-outputs
```

> [!TIP]
> Ensure your `.bloc.yaml` files are placed inside the target output directories and have `path: ""` specified in the YAML configuration. This allows `build_runner` to resolve relative file dependencies and automatically run downstream builders like `json_serializable` in the correct sequence.

---

## Usage Mode 2: Command Line Interface (CLI)

You can also run the generator directly via the Dart command line:

### 1. Bloc Generation
Run state, event, bloc, or all generator modes:
```bash
# Generate State, Event, and Bloc
dart run bin/generator.dart bloc all path/to/config.yaml

# Generate only State
dart run bin/generator.dart bloc state path/to/config.yaml

# Generate only Event
dart run bin/generator.dart bloc event path/to/config.yaml
```

### 2. i18n Translation Generation
Generate localization class delegates:
```bash
dart run bin/generator.dart i18n --yaml path/to/strings.yaml --output path/to/output_dir/
```

---

## YAML Configuration Formats

### Bloc Configuration (`.bloc.yaml`)

```yaml
part: demo.dart
path: "" # Keep empty when using build_runner so files generate in the same directory
import: "import '../../models.dart';" # Custom imports required by your state fields

state:
  name: DemoState
  equal: true # Generates Equatable equality comparison
  dest: .d.dart # State file destination name extension
  props:
    - 'DictWord word=const DictWord(word: "")'
    - DictStatus status=DictStatus.init

event:
  name: DemoEvent
  dest: .e.dart
  events:
    SomeEvent:
    FinishEvent:
    EventWithProps~props:
      - DictError? error
      - bool overwrite=false

bloc:
  name: DemoBloc
  dest: .b.dart
  useHydrate: false # Optional hydrated bloc configuration
  useReplay: true   # Enables ReplayBlocMixin
```

### i18n Configuration (`.i18n.yaml`)

```yaml
settings:
  l18n: l19n
  delegate: TRDelegate
  helper: StringHelper
  default_object: TR
  default_class: TS

Languages:
  - locale: en_US
    name: English
    default: true
  - locale: zh_CN
    name: Chinese

Shared:
  AppName: MyAppName

Strings:
  HourMeasure:
    - Hours
    - 小时
  MinuteMeasure:
    - Minutes
    - 分钟
```

---

## Example Project

A complete working example demonstrating configuration files, parent class inheritance, models integration, and successful build runner execution can be found in the [example/](file:///Users/sam/Project/generator/example) directory.
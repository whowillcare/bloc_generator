# Skill: Bloc Code Generation with `bloc_gen_plus`

This guide explains how to generate, extend, and implement BLoC classes (State, Event, and Bloc) using YAML specifications and automation tools within a project utilizing `bloc_gen_plus`.

---

## 1. Configuring Build Pipelines

To automate code generation when YAML definitions change, you must configure a build pipeline.

### Option A: `build.yaml` (Recommended for Dart/Flutter projects)
Create a [build.yaml](file:///home/sam/Projects/bloc_generator/build.yaml) file in the root of your project to register the `bloc_builder` builder. Below is the standard configuration:

```yaml
targets:
  $default:
    builders:
      bloc_gen_plus|bloc_builder:
        enabled: true
        generate_for:
          - lib/bloc/*.yaml  # Specify where your Bloc specification files are located
```

### Option B: `build.xml` (For Ant/XML-based Build Automation)
If your project uses a generic XML-based task runner (e.g., Apache Ant), you can specify target scripts to run the command-line interface (CLI) of the generator. Create a `build.xml` in your project root:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project name="bloc_generator_automation" default="build-all">
    <!-- Target to run the standard Dart build_runner -->
    <target name="build-all" description="Build all generated files using build_runner">
        <exec executable="dart" failonerror="true">
            <arg value="run"/>
            <arg value="build_runner"/>
            <arg value="build"/>
            <arg value="--delete-conflicting-outputs"/>
        </exec>
    </target>

    <!-- Target to generate/update a specific Bloc using CLI -->
    <target name="generate-bloc" description="Generate a single Bloc from YAML using the CLI generator">
        <property name="yaml.file" value="lib/bloc/demo.yaml"/>
        <exec executable="dart" failonerror="true">
            <arg value="run"/>
            <arg value="bin/generator.dart"/>
            <arg value="bloc"/>
            <arg value="all"/>
            <arg value="${yaml.file}"/>
        </exec>
    </target>
</project>
```

---

## 2. Creating the Bloc YAML Specification

To generate a BLoC, create a `.yaml` file under your registered target directory (e.g., `lib/bloc/demo.yaml`).

### Example Specification (`demo.yaml`)
Refer to the example configuration: [demo.yaml](file:///home/sam/Projects/bloc_generator/example/lib/bloc/demo.yaml).

```yaml
part: demo.dart          # The name of the main part file containing imports and part declarations
path: "demobloc"         # Subdirectory name (relative to YAML location) to place generated files. Use "" for same-directory generation.
import: "import '../../models.dart';" # Custom imports required by the fields in your state class

state:
  name: DemoState        # Name of the generated State class
  equal: true            # Set to true to extend Equatable and generate equality comparisons
  dest: .d.dart          # Extension for the generated state part file (e.g., demo.d.dart)
  useJson: false         # Set to true to generate @JsonSerializable and fromJson/toJson methods
  props:                 # List of fields defined as 'Type name[=default_value][//comment][(jk@JsonKeyName)]'
    - 'DictWord word=const DictWord(word: "")'
    - DictStatus status=DictStatus.init // Current status of the word dictionary
    - 'DictAction? action // Current action (jk@Action)'

event:
  name: DemoEvent        # Name of the base sealed class for all events
  dest: .e.dart          # Extension for the generated event part file
  events:                # List/map of child events. Use ~shortcut to generate adding-shortcut methods
    SomeEvent:
    FinishEvent:
    CoolEvent~cool:
    EventWithProps~withProps:
      - String details
      - bool isImportant=false

bloc:
  name: DemoBloc         # Name of the generated Bloc class
  dest: .b.dart          # Extension for the generated bloc part file
  useHydrate: false      # Set to true to inherit from HydratedBloc instead of Bloc
  useReplay: true        # Set to true to enable ReplayBlocMixin
```

---

## 3. Running Code Generation

To trigger generation and compile the YAML files:

```bash
# Using build runner (recommended)
dart run build_runner build --delete-conflicting-outputs

# Alternatively, scan and generate using the shortcut CLI mode
dart run bin/generator.dart
```

This generates:
1. `demobloc/demo.dart` (The main barrel/part orchestrator file containing all `part` directives)
2. `demobloc/demo.s.dart` (The state class definition)
3. `demobloc/demo.e.dart` (The sealed base event and all subclassed events)
4. `demobloc/demo.b.dart` (The Bloc class file)

---

## 4. Implementing Custom Logic in Placeholders

When files are initially generated, you must write the actual application logic within the designated placeholders:

### A. Event Handler Functions (`demo.b.dart`)
The generator populates the generated Bloc constructor with event-to-handler maps (`on<Event>((event, emit) => ...)`) and corresponding template placeholder methods containing a `//TODO add your code here` comment:

```dart
Future<void> _onSomeEvent(SomeEvent event, Emitter<DemoState> emit) async {
  //TODO add your code here
  // Example implementation:
  emit(state.copyWith(status: DictStatus.loading));
}
```

> [!IMPORTANT]
> **Safe Iteration Guarantee**: If you add new events to the YAML and run the generator again, the generator parses your existing `demo.b.dart` file. It **ONLY appends** the new handler registration calls and placeholder methods, leaving all your previously written custom business logic untouched. Do not modify the structure of the constructor or method signatures manually to prevent syntax errors during updating.

### B. Custom Helper Logic & Imports
- **Main/Container File**: In `demo.dart` (or `demo.c.dart` if using `partcode: true`), you can add custom functions, helper mixins, and top-level definitions that your Bloc needs to reference.
- **State/Event Files**: Do **NOT** write custom logic inside the generated state (`.s.dart` / `.d.dart`) or event (`.e.dart`) files. They are completely regenerated and overwritten on every build. Instead, configure custom fields/classes via `import` and `props` in the YAML, and perform transformation logic in the Bloc handlers.

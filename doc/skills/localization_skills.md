# Skill: Localization and Translation Management with `i18n_builder`

This guide details the localization workflow for developers and AI agents using the `i18n_builder` code generator.

---

## 1. The Core Rule: Zero Hardcoded User-Facing Strings

> [!IMPORTANT]
> **Strict Guideline**: Do not hardcode user-facing text strings directly in Dart source code files. Every user-facing string must be managed through the translation configuration system and referenced programmatically.

---

## 2. Step-by-Step Translation Workflow

Whenever a new user-facing string is required in your UI or logic code:

### Step 1: Search Existing Translations
Always search the generated localization helper file first (usually [StringHelper.dart](../../example/lib/i18n/StringHelper.dart)) to see if a suitable key already exists.
- **Why Search the Helper First?** The helper file compiles and aggregates all keys from all partitioned translation files into one place. This makes searching for existing definitions much faster and avoids scanning multiple configuration files.
- If the key is not in the helper, you can also cross-check the primary configuration file [strings.yaml](../../example/lib/i18n/strings.yaml) or search the individual sub-files within the include subdirectory.
- If it exists, retrieve and reuse the key.

### Step 2: Partition and Add the String to the Sub-YAML Files
If the translation key does not exist, do not dump it into the root [strings.yaml](../../example/lib/i18n/strings.yaml). Instead, organize and partition your translation files logically into a subdirectory:

1. **Leverage the `include` Directive**:
   Ensure your main [strings.yaml](../../example/lib/i18n/strings.yaml) is configured to include a subdirectory of translation files in the `settings` block:
   ```yaml
   settings:
     l18n: l19n
     delegate: TRDelegate
     helper: StringHelper
     default_object: TR
     default_class: TS
     include: strings  # Automatically includes all recursively found YAML files in the 'strings' subdirectory
   ```

2. **Partition Logically**:
   Identify or create a YAML file in the `strings` subdirectory (e.g., `sleep.yaml` or `measures.yaml`) that logically corresponds to the domain/feature of the string you are creating.
   - *Example*: All sleep tracking UI or analysis strings should go into `strings/sleep.yaml`. Measurement metrics should go into `strings/measures.yaml`.
   - If a new feature or domain is introduced, create a new sub-file (e.g., `strings/settings.yaml`) to keep strings organized, human-friendly, and modular.

3. **Format Translations**:
   Add the new translation keys directly to the partitioned file. Note that files in the `include` subdirectory **must not** start with a `Strings:` root key; their top-level keys are merged directly into the global translation namespace.
   - Maintain the exact order of translations specified in the `Languages` section of [strings.yaml](../../example/lib/i18n/strings.yaml) (e.g. English first, Chinese second):
     ```yaml
     NewGreeting:
       - Hello!      # English (Default/First)
       - 你好！       # Chinese (Second)
     ```
   - If you need to define parameterized strings (translations mapping dynamically based on a key), use a map format under the key:
     ```yaml
     SleepAnalysisDesc:
       - init: Start your sleep tracking.
         good: You slept well today.
       - init: 开始追踪您的睡眠。
         good: 您今天睡得很好。
     ```

### Step 3: Run the Code Generator
Regenerate the strongly-typed Dart files to create the helper variables and method bindings for the new key:

```bash
# Using build runner (recommended)
dart run build_runner build --delete-conflicting-outputs

# Or using the shortcut CLI mode
dart run bin/generator.dart
```

This compiles your YAML file and generates/updates the localization classes (e.g., helper file `StringHelper.dart`, interface `TS.dart`, and locale implementations `English.dart` and `Chinese.dart`).

---

## 3. Configuration to Code Mapping

The APIs generated in Dart depend on the properties configured in your YAML's `settings` section:

```yaml
settings:
  l18n: l19n               # Name of the BuildContext extension getter (e.g. context.l19n)
  delegate: TRDelegate     # Name of the LocalizationsDelegate class
  helper: StringHelper     # Name of the generated helper wrapper class
  default_object: TR       # Name of the global accessor instance (e.g., TR.someKey)
  default_class: TS        # Name of the generated translation interface class
```

---

## 4. Referencing Localized Strings in Dart Code

Always access strings programmatically using one of the following generated patterns:

### Pattern A: BuildContext Extension (Preferred for Widgets)
Use the BuildContext extension named after the `l18n` setting (e.g., `l19n` in the example config):

```dart
import 'path/to/i18n/StringHelper.dart';

@override
Widget build(BuildContext context) {
  return Text(
    context.l19n.NewGreeting, // Resolves to current locale's translation
  );
}
```

### Pattern B: Global Object Reference (For non-widget files or quick access)
Use the global default object variable (e.g., `TR` in the example config):

```dart
import 'path/to/i18n/StringHelper.dart';

void logStatus() {
  print(TR.SharedAppName); // Accesses the global language delegate instance
}
```

### Pattern C: Parameterized Method Call
If the translation in the YAML contains mapped values, the generator automatically generates a method accepting a lookup key:

```dart
// Mapped translation in strings.yaml:
// SleepAnalysisDesc:
//   - init: Start your sleep tracking.
//   - init: 开始追踪您的睡眠。

// In Dart code:
String description = TR.SleepAnalysisDesc('init'); // Returns 'Start your sleep tracking.' in English
```

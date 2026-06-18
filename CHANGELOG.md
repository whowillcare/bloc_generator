## 1.2.2

* Configured builders to only run on the root package. Checks input package names against the root package name to skip builder execution for external dependency packages.

## 1.2.1

* Updated localization skill documentation (`localization_skills.md`) to use relative paths, search the helper Dart file first, leverage the `include` directive, and partition translation sub-files logically.
* Added `path_convention_skill.md` defining Markdown relative path conventions for this repository.

## 1.2.0

* Added AI-friendly skill documentation under `doc/skills/` directory for developer and automated agent guidance.
* Added `bloc_generate_skills.md` explaining Bloc specification format, build systems (`build.yaml` and `build.xml`), and custom placeholder implementation.
* Added `localization_skills.md` documenting strict localization workflows, translation settings mapping, and programmatic accessing via BuildContext or global delegates.

## 1.1.0

* Added support for loading and merging translation strings from a subdirectory using the `include` setting in the main translation YAML.
* Enhanced `I18nBuilder` build step dependency preloading via `buildStep.readAsString` to track changes in the `include` folder and trigger incremental rebuilds in `build_runner`.
* Configured `i18n_builder` to write the `.i18n.dart` marker files directly to the build runner's cache (`build_to: cache`) instead of polluting the source tree.
* Cleaned up duplicate and verbose manual path generation logic.

## 1.0.2

* Implemented `shouldBuild` checks in `build_runner` builders to avoid unnecessary builds and skip execution for unmodified config files.
* Enhanced builder caching by verifying that all expected output files physically exist before skipping a build.
* Implemented `preloadReferencedFiles` preloading for user-defined files (like repo classes or parent state classes) using `buildStep.readAsString` to prevent build crashes in sandboxed builder environments.
* Added CLI argument forwarding support, enabling flags like `-v` or `--verbose` passed to `generator shortcut` to be forwarded directly to the under-the-hood `build_runner` process.
* Unified and cleaned caching logging outputs, resolving build warning pollution.

## 1.0.1

* Widened the dependency constraint for the `build` package to resolve version solving conflicts in consumer projects using newer `analyzer` and `test` versions.

## 1.0.0

* Initial release of `bloc_gen_plus`.
* Ported legacy python code generators (`stategen.py` and `l18n_gen.py`) to Dart.
* Added standard CLI tool interface supporting `bloc`, `i18n`, and `shortcut` generation.
* Implemented `i18n_builder` and `bloc_builder` for integration with standard Flutter `build_runner`.

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

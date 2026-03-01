# Repository Guidelines

## Project Structure & Module Organization
Godot’s engine code is split by runtime layer and platform. Core runtime code lives in `core/`, scene tree systems in `scene/`, rendering/audio/physics servers in `servers/`, and editor-only code in `editor/`. Platform backends are in `platform/`, optional features in `modules/`, and bundled dependencies in `thirdparty/` (vendor code). Build entrypoints are `SConstruct` plus per-directory `SCsub` files. Tests are under `tests/` with mirrored areas such as `tests/core/`, `tests/scene/`, and `tests/servers/`.

## Build, Test, and Development Commands
Use SCons from the repo root.
- `scons platform=linuxbsd target=editor dev_build=yes tests=yes` builds an editor binary with developer checks and unit tests.
- `./bin/godot.linuxbsd.editor.dev.x86_64 --test` runs the doctest suite (binary suffix varies by platform/arch).
- `python3 tests/create_test.py MeshInstance3D core` scaffolds `tests/core/test_mesh_instance_3d.h` (use `-i` to auto-insert include in `tests/test_main.cpp`).
- `pre-commit run -a` runs formatting/lint hooks before committing.
- Do not run multiple `scons` builds concurrently in one checkout; use separate worktrees for parallel jobs.

## Coding Style & Naming Conventions
Follow `.editorconfig` and `.clang-format` exactly. C/C++/headers use tabs with visual width 4 and max line length 120. Python, `SConstruct`, and `SCsub` use 4 spaces. Use snake_case for file names (for example, `test_node_path.cpp`) and keep module/platform naming consistent with existing trees. Run `pre-commit` to apply `clang-format`, Ruff, mypy, and other hooks.

## Testing Guidelines
The test framework is doctest (`tests/test_main.cpp`). Add tests in the matching subsystem folder, typically as `test_<feature>.cpp`; when using the scaffold script, it generates `test_<feature>.h` and you include it from `tests/test_main.cpp`. Keep tests deterministic and include regression coverage for bug fixes plus success/failure paths for new features. Build with `tests=yes`, then run with `--test`; pass doctest filters after `--test` when narrowing scope.

## Security & Configuration Tips
Treat repo scripts and hooks as executable code. Before running `python` helpers or `pre-commit` on unfamiliar branches, review changes in `SConstruct`, `SCsub`, `.pre-commit-config.yaml`, and `tests/**/*.py`. Never commit or paste secrets from env/config output; redact tokens in logs and PRs. Avoid destructive cleanup commands unless requested and path-scoped.

## Commit & Pull Request Guidelines
Keep commits focused and bisectable; one topic per PR. Commit titles should be imperative, capitalized, and usually under 72 chars, optionally prefixed by area (for example, `Core: Fix ObjectID validation`). In PR descriptions, link issues with closing keywords (for example, `Fixes #12345`). Include: problem statement, approach, test evidence, and screenshots/videos for UI changes. Update class reference XML when changing script-exposed APIs.

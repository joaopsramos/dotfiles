# Repository Guidelines

## Project Structure & Module Organization

`shell.qml` is the Quickshell entry point. `Theme.qml` centralizes colors and sizing; `Time.qml` supplies shared time state. Feature directories include `bar/`, `notifications/`, `session/`, `overlays/`, `downloads/`, `privacy/`, and `pomodoro/`. Bar modules group related QML widgets and Python collectors, such as `bar/network/`. Reusable widgets belong in `components/`; shared services belong in `services/`. Regression tests live in `tests/`. Timer sounds and attribution are in `pomodoro/sounds/`.

## Build, Test, and Development Commands

Run commands from the repository root:

- `quickshell -p .` — launch this shell configuration in a desktop session.
- `python3 -m unittest discover -s tests -v` — run the complete regression suite.
- `python3 -m unittest discover -s tests -p 'test_collectors.py' -v` — run collector tests only.
- `qmlformat -i path/to/Widget.qml` — format a changed QML file using `.qmlformat.ini`.

There is no separate compilation step or package build script. Runtime features depend on Linux facilities and installed desktop utilities.

## Coding Style & Naming Conventions

Never include tooltips in the UI. Do not add tooltip text or enable inherited tooltips; disable them explicitly when reusing a component that provides them.

Use four-space indentation. QML formatting specifies Unix newlines and essential semicolons. Name QML component files in PascalCase, properties and functions in camelCase, and Python modules and functions in snake_case. Match surrounding import and quoting styles. Reuse `Theme` values and existing components before introducing duplicate styling. Keep hardware collection in Python helpers and expose state through shared QML services where appropriate.

## Testing Guidelines

Tests use Python's standard-library `unittest`, with mocks and temporary directories for isolation. Name test files `test_*.py` and methods `test_<behavior>`. Cover collector parsing, failure handling, and changed widget behavior. QML integration tests launch an offscreen Quickshell process and skip when Quickshell is unavailable. No numeric coverage threshold is configured. For visual changes, also inspect the affected panel in a desktop session.

## Commit & Pull Request Guidelines

Git history is unavailable in this checkout, so no established commit convention can be verified. Use concise, imperative subjects, such as `Fix network polling after reconnect`. Keep changes focused. Pull requests should explain the behavior change, list validation performed, link relevant issues, and include screenshots for visible UI changes. Preserve sound licensing and attribution when modifying assets.

# Codex Project Instructions

## Project

This is a Godot 4 business simulation written in typed GDScript.

## Architecture

- Keep economic simulation logic independent from graphics and UI.
- Prefer data-driven systems rather than hard-coding individual products,
  technologies, industries, or scenarios.
- The simulation should be deterministic when given the same seed and player actions.
- Keep major systems modular and reasonably easy to test independently.
- Tutorial and sandbox modes should use the same underlying simulation systems.

## Development

- Before making substantial architectural changes, inspect the existing implementation.
- Preserve working functionality unless the task explicitly requires changing it.
- Prefer simple implementations over unnecessary abstraction.
- Add tests for important simulation logic where practical.
- Run relevant tests after modifying simulation code.
- Fix errors introduced by your changes before finishing a task.
- Do not add external dependencies unless they provide a clear benefit.
- Keep documentation synchronized with significant architectural changes.

## Git

- Do not rewrite or delete existing Git history.
- Do not create branches unless explicitly requested.
- Do not commit automatically unless explicitly requested.
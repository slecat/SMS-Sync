# Root AGENTS Design

Date: 2026-03-15

## Problem

The repository has a root `README.md` and multiple application-specific directories, but it does not have a root-level `AGENTS.md` that tells coding agents how to navigate the workspace, which directories are safe to change, and which commands map to each app.

## Goal

Add a root `AGENTS.md` that gives agents enough repository-level context to work safely in this multi-project workspace without duplicating the full human-facing README.

## Scope

- Create a root `AGENTS.md`
- Document the real code root at `sms-sync/`
- Summarize the responsibilities of `mobile`, `desktop`, and `server`
- List the main install, run, test, and lint commands that already exist
- Add repository guardrails for generated artifacts, vendored code, and unrelated subprojects
- Clarify how `README.md` and `AGENTS.md` should stay in sync

## Non-Goals

- Add new scripts, scaffolding, or package manifests
- Reorganize the repository layout
- Modify application code in `mobile`, `desktop`, or `server`
- Replace the existing README files
- Add per-subproject `AGENTS.md` files

## Approach

Create a concise Chinese `AGENTS.md` in the repository root. The file should focus on execution-oriented guidance for coding agents: where the code lives, which commands are valid, which directories should usually be left alone, and what documentation must be updated when commands or layout change. The content should stay short and specific so that it remains easier to maintain than the root README.

## Risks

- Some commands in the existing READMEs are documented from a human setup perspective; the new `AGENTS.md` must avoid inventing commands that are not present in the workspace.
- The repository already contains build outputs and vendored dependencies, so the guardrails need to be explicit enough to prevent accidental edits.
- The workspace is currently dirty, so this work should be isolated to new documentation files only.

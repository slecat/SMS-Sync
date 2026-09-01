# Root AGENTS Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a root `AGENTS.md` that helps coding agents work safely in this multi-project repository.

**Architecture:** Keep the implementation documentation-only. Create a repository-level design note and an execution-oriented `AGENTS.md` in the root that references the existing `sms-sync/` subprojects and commands without changing application code or introducing new tooling.

**Tech Stack:** Markdown, git workspace inspection, existing Node.js and Flutter project commands.

---

### Task 1: Capture the approved repository-level design

**Files:**
- Create: `docs/plans/2026-03-15-root-agents-design.md`

**Step 1: Write the initial document**

Draft the problem, goal, scope, non-goals, approach, and risks for a root-level `AGENTS.md`.

**Step 2: Verify against the repository**

Run: `Get-ChildItem -Force`
Expected: confirm the repository root contains `README.md`, `sms-sync/`, and no existing root `AGENTS.md`.

**Step 3: Save the design**

Write the approved design to `docs/plans/2026-03-15-root-agents-design.md`.

### Task 2: Create the execution plan for the documentation work

**Files:**
- Create: `docs/plans/2026-03-15-root-agents-implementation.md`

**Step 1: Break the work into small actions**

List the exact documentation files to create and the repository checks to run before completion.

**Step 2: Verify command sources**

Run: `Get-Content README.md`
Expected: identify the install and run commands already documented at the repository level.

**Step 3: Save the plan**

Write the implementation plan with repository checks and verification steps.

### Task 3: Add the root AGENTS guide

**Files:**
- Create: `AGENTS.md`

**Step 1: Draft the file**

Write a concise Chinese guide with sections for repository overview, project structure, common commands, editing guardrails, and documentation sync rules.

**Step 2: Verify file paths and commands**

Run: `Get-ChildItem -Force sms-sync`
Expected: confirm `desktop`, `mobile`, and `server` exist under `sms-sync/`.

**Step 3: Save the final file**

Write the approved content to `AGENTS.md`.

### Task 4: Verify the new documentation

**Files:**
- Verify: `AGENTS.md`
- Verify: `docs/plans/2026-03-15-root-agents-design.md`
- Verify: `docs/plans/2026-03-15-root-agents-implementation.md`

**Step 1: Inspect the new files**

Run: `Get-Content AGENTS.md`
Expected: the file contains repository layout, commands, and guardrails.

**Step 2: Confirm workspace impact**

Run: `git status --short`
Expected: only the newly added documentation files appear from this task.

**Step 3: Commit when appropriate**

If the user requests a commit later, stage only the three new documentation files and create a documentation-focused commit message.

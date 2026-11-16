---
name: commit
description: >-
  Use when the user asks to commit, sync with teammates or main, or types
  /commit or @commit. Fetches origin, checks whether teammates pushed commits
  or merged into main, commits local changes on the working branch, safely
  merges latest updates and resolves conflicts, verifies Flutter checks/tests,
  pushes the working branch, and automatically integrates and pushes to main.
---

# Smart Commit, Teammate Sync & Main Push

Run this workflow when the user triggers `/commit`, `@commit`, or asks to commit their work, check teammate pushes/merges, bring their branch up to date, and optionally push to `main`.

## Step 1: Fetch Origin & Check Teammate / Main Status

Run a non-destructive fetch first so remote state is accurate:

```powershell
git fetch origin --prune
git branch --show-current
git status -uall --short
```

1. **Verify Current Branch:**
   - If `git branch --show-current` is empty (detached HEAD), **STOP immediately** and ask the user to checkout a valid branch before proceeding.

2. **Inspect Remote Updates (`HEAD` vs `origin/main`):**

```powershell
git rev-list --left-right --count HEAD...origin/main
git log --oneline --decorate HEAD..origin/main
git for-each-ref --format="%(refname:short) | %(committerdate:iso8601) | %(authorname)" refs/remotes/origin
```

3. **Check Teammate Remote Branches with Squash-PR Awareness:**
   - For every teammate remote branch (any `origin/<other>` besides `origin/HEAD`, `origin/main`, and `origin/<branch>`):
   - **Do NOT rely solely on commit hashes** (`git log origin/main..<remote_branch>`), because if a teammate's PR was merged via **Squash and merge** or **Rebase and merge**, Git commit hashes differ and will trigger a false alarm!
   - Use three-dot diff to check if there are actual code differences between `origin/main` and the teammate branch:

```powershell
git diff --stat origin/main...<remote_branch>
```

   - **If the three-dot diff is empty:** The teammate's changes have already been merged into `main` (via PR squash/rebase). Report it as up-to-date and merged.
   - **If the three-dot diff has changes:** The teammate branch has unmerged work in progress (WIP). Check commit history:

```powershell
git log --oneline origin/main..<remote_branch>
```

### Report Findings Clearly

Before modifying git history, summarize for the user:
1. **Current branch & local changes:** branch name, count of modified/untracked files.
2. **`origin/main` status:** whether `origin/main` has new commits ahead of local `HEAD`, or if it is up to date.
3. **Teammate branch status:** whether teammate branches (e.g. `origin/YH`) are already merged into `main`, or have unmerged WIP.
4. **Team Safety Rule on Teammate Branches:**
   - **Default action:** Sync with `origin/main` only. **NEVER** merge a teammate's WIP branch into `<branch>` or `main` unless the teammate or user explicitly requests integrating that specific branch. Teammates may have experimental or unfinished work on their branch.

---

## Step 2: Pre-Commit Cleanup, Safety & Workspace Rules Check

Before staging files, inspect `git status -uall --short` and top-level repository folders:

1. **Check for unrelated or stray folders/files:**
   - Scan modified, untracked, and top-level folders (such as `tmp/`, `temp/`, `scratch/`, `logs/`, `out/`, unexpected exports, or leftover test/script directories that do not belong to `lib/`, `test/`, `assets/`, `docs/`, `tool/`, `supabase/`, `.agents/`, or standard Flutter platform folders).
   - **Safe auto-cleanup:** Delete empty leftover scratch folders (e.g. empty `tmp/`) and obvious temp/OS junk (`.DS_Store`, `Thumbs.db`).
   - **Ask before deleting non-empty folders:** If a non-empty folder looks unrelated or ambiguous, list the folder path and files and **ask the user before deleting** it.
   - **Windows Line Endings:** On Windows, avoid repeatedly reverting line endings (`CRLF` vs `LF`) with `git checkout -- <file>` if Git autocrlf marks it dirty again. Only discard files that have genuinely zero whitespace diff (`git diff -w --stat` is empty).

2. **No secrets or temp files:**
   - Confirm no `.env`, `supabase/functions/.env*`, private keys, keystores, or debug logs (`*.log`) are staged or committed.

3. **All required new files are included:**
   - Do not forget untracked files required for tests/builds (e.g. `lib/`, `assets/`, `test/`).

4. **CRITICAL: Database Schema Sync & Disaster Recovery Check (`AGENTS.md` / `GEMINI.md`):**
   - Check if database tables, columns, constraints, RLS policies, triggers, views, or Supabase Edge Functions were modified:

```powershell
git diff --name-only HEAD | Select-String -Pattern "supabase|models|services"
```

   - If database structures were altered, **verify that `docs/supabase_schema.sql` is also updated** and all DDL statements remain idempotent (`IF NOT EXISTS`, `CREATE OR REPLACE`, `ON CONFLICT DO NOTHING`). If missing, update `docs/supabase_schema.sql` before committing!

5. **Branch Check:**
   - If currently on `main` with uncommitted feature work, prompt the user to create or switch to a working feature branch (e.g. `CK`), unless the user explicitly intended to commit directly on `main`.

---

## Step 3: Commit Local Work on the Working Branch

1. **Check if Working Tree Has Changes:**

```powershell
git status --porcelain
```

   - **If working tree is clean:** Skip staging and commit creation! Report: *"Working tree clean; skipping commit and proceeding to sync and verification."*
   - **If working tree has changes:**
     - Stage intended verified files (never blind-stage secrets or `.env` files).
     - Inspect `git diff --cached --stat`.
     - Write a concise Conventional Commit message (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`) accurately describing the changes.
     - **PowerShell Safe Execution:** Escape any special characters (like `$`, `` ` ``, `"`) in commit messages to prevent PowerShell variable evaluation.
     - Commit on `<branch>`:

```powershell
git commit -m "<subject>" -m "<optional bullet body>"
```

---

## Step 4: Merge Latest Updates & Resolve Conflicts

1. **Merge `origin/main` into `<branch>` (if `origin/main` has new commits):**

```powershell
git merge origin/main --no-edit
```

2. **Conflict Resolution Rules & Safe Exit:**
   - **Stop and ask user on conflict:** If any merge conflict occurs, **DO NOT guess or auto-resolve**. **STOP immediately** and present:
     - Conflicted files list (`git diff --name-only --diff-filter=U`).
     - Specific conflicting code snippets.
     - **Safe Abort Option:** Explicitly inform the user that they can run `git merge --abort` anytime to return safely to the pre-merge state.
   - **Never** run `git checkout --ours` or `--theirs` blindly on shared code.
   - Once conflicts are resolved with user agreement, stage the resolved files and finish the merge (`git commit --no-edit`).

3. **Dependency Change Detection:**
   - Check if the merge updated dependencies:

```powershell
git diff --name-only HEAD@{1} HEAD | Select-String -Pattern "pubspec"
```

   - If `pubspec.yaml` or `pubspec.lock` was modified by the merge, run `flutter pub get` immediately before running static analysis or tests.

---

## Step 5: Verify Build, Static Analysis & Tests

After merges and conflict resolutions are finished, run verification:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

*(Note: If `pubspec.yaml` was updated in Step 4, omit `--no-pub` so new dependencies resolve cleanly).*

- **Strict Test Quality Guardrail:**
  - `flutter analyze` must pass with zero errors.
  - If tests fail:
    - Check if the failures were caused by the current changes or merge.
    - **Never assume test failures are "pre-existing" without proof.**
    - If any test fails, STOP and report the exact test failures to the user. Do NOT push broken code to `main`.

---

## Step 6: Push Working Branch & Automated Safe Integration into Main

1. **Always Push the Working Branch First:**

```powershell
git push origin <branch>
```

2. **Automated Integration into `main`:**
   - **Case A: Current branch `<branch>` IS `main`:**
     - The working branch is already `main`. Pushing `origin main` completes the push. No merge step needed.
   - **Case B: Current branch `<branch>` is a feature branch (e.g. `CK`):**
     - **Automated Main Integration:** As long as Step 5 verifications (`flutter analyze` and `flutter test`) passed with zero errors, automatically integrate `<branch>` into `main` and push to `origin/main` without pausing for confirmation:

```powershell
git checkout main
git pull --ff-only origin main
git merge <branch> --no-edit
git push origin main
git checkout <branch>
```

   - **Divergence Guard:** If `git pull --ff-only origin main` fails (local `main` diverged from remote), **STOP**, return immediately to `<branch>` (`git checkout <branch>`), and alert the user so local `main` can be safely realigned without risking data loss.
   - **Always Return to `<branch>`:** Ensure the working directory returns to the feature branch `<branch>` (`git checkout <branch>`) so subsequent edits remain on the feature branch.

3. **If `origin/main` rejects direct push (Branch Protection):**
   - Keep `<branch>` pushed on `origin`.
   - Ensure the user is back on `<branch>` (`git checkout <branch>`).
   - If `gh` CLI is installed, offer to create a Pull Request; otherwise provide the GitHub compare/PR link:
     `https://github.com/<owner>/<repo>/compare/main...<branch>`

4. **Final Status & Bilingual Report:**
   - Run `git status` and `git log --graph --oneline --decorate -n 6 HEAD`.
   - Present a clear report in **both simple English and Simplified Chinese (简体中文)** containing:
     - **Conflict status:** "No conflicts" or list of resolved files.
     - **What was done:** Plain-language summary of branch status, commits created, and push status.
     - **Verification results:** Exact `flutter analyze` and `flutter test` outcomes.
     - **Main integration status:** Confirm that changes were automatically merged into `main` and pushed to `origin/main`.
     - **中文翻译 / Chinese Translation:** Complete Simplified Chinese version of the report.

---

## Guardrails

- **Never** run `git push --force` or `git push --force-with-lease` on `main` or shared branches.
- **Never** discard uncommitted work (`git reset --hard`, `git clean -fd`) or delete non-empty folders without explicit user confirmation.
- **Never** merge teammate WIP branches into `main` without explicit teammate/user authorization.
- **Never** leave the repository stuck in an unhandled `MERGING` state without offering `git merge --abort`.
- **Never** push to `main` if `flutter analyze` has errors or newly introduced test failures occur.

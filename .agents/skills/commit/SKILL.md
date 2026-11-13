---
name: commit
description: >-
  Use when the user asks to commit, sync with teammates or main, or types
  /commit or @commit. Fetches origin, checks whether teammates pushed commits
  or merged into main, commits local changes on the working branch, safely
  merges latest updates and resolves conflicts, verifies Flutter checks/tests,
  and pushes both the working branch and main.
---

# Smart Commit, Teammate Sync & Main Push

Run this workflow when the user triggers `/commit`, `@commit`, or asks to commit their work, check teammate pushes/merges, bring their branch up to date, and push to `main`.

## Step 1: Fetch Origin & Check Teammate / Main Status

Run a non-destructive fetch first so remote state is accurate:

```powershell
git fetch origin --prune
git branch --show-current
git status -uall --short
```

Inspect what changed remotely compared to the current branch (`<branch>`) and `origin/main`:

```powershell
git rev-list --left-right --count HEAD...origin/main
git log --oneline --decorate HEAD..origin/main
git for-each-ref --format="%(refname:short) | %(committerdate:iso8601) | %(authorname)" refs/remotes/origin
```

For every teammate remote branch (any `origin/<other>` besides `origin/HEAD`, `origin/main`, and `origin/<branch>`), check if it has unmerged commits ahead of `origin/main`:

```powershell
git log --oneline origin/main..<remote_branch>
git diff --stat origin/main..<remote_branch>
```

Check whether any files changed in `HEAD..origin/main` or `origin/main..<remote_branch>` overlap with the user's locally modified/untracked files.

### Report Findings Clearly

Before modifying git history, summarize for the user:
1. **Current branch & local changes:** branch name, count of modified/untracked files.
2. **`origin/main` status:** whether teammates already merged commits into `main` (`HEAD..origin/main` commits), or if `origin/main` has no new commits.
3. **Teammate & all branch status:** check whether **all branch commits** (including teammate branches like `origin/YH` and local feature branches) are merged correctly into `main`. Report clearly if every branch is up to date and merged into `main`, or list any unmerged commits (with commit hash, author, date, summary, and overlapping files).

If an **unmerged** teammate branch has commits ahead of `origin/main` (especially if files overlap), or if anything is ambiguous or confusing, **STOP and ask the user** before proceeding:
- Option A: Sync with `origin/main` only (keep teammate's unmerged WIP separate).
- Option B: Merge `origin/<teammate>` as well so everything is combined before pushing to `main`.

If `HEAD..origin/main` has commits (already merged to `main`) and no unmerged teammate branches need confirmation, proceed automatically through the steps below.

---

## Step 2: Pre-Commit Cleanup, Safety & Workspace Rules Check

Before staging files, inspect the working tree (`git status -uall --short`) and top-level repository folders to catch both **unrelated/stray folders** and **files that must not be committed**:

1. **Check for unrelated or stray folders/files:**
   - Scan modified, untracked, and top-level folders (such as `tmp/`, `temp/`, `scratch/`, `logs/`, `out/`, unexpected exports, or leftover test/script directories that do not belong to `lib/`, `test/`, `assets/`, `docs/`, `tool/`, `supabase/`, `.agents/`, or standard Flutter platform folders).
   - Check for whitespace/line-ending-only modified files (`git diff --stat` vs `git diff -w --stat` showing zero real diff).
   - **Cleanup action:**
     - **Safe auto-cleanup:** Delete empty leftover scratch folders (e.g. empty `tmp/`), obvious temp/OS junk (`.DS_Store`, `Thumbs.db`), and restore tracked files with zero real diff (`git checkout -- <file>`) — report each removed/restored item.
     - **Ask before deleting non-empty folders:** If a non-empty folder looks unrelated or ambiguous (for example, contains files you did not inspect or might be experimental work), list the folder path and files and **ask the user for confirmation before deleting** it (or exclude it from staging if they want to keep it locally).
2. **No secrets or temp files:** Confirm no `.env`, `supabase/functions/.env*`, private keys, keystores, or debug logs (`*.log`) are included in the commit.
3. **All required new files are included:** Do not forget untracked directories needed for build/tests (e.g. `lib/l10n/`, new services/widgets, `test/` files).
4. **Database schema sync (`AGENTS.md` / `GEMINI.md`):** If database tables, columns, RLS policies, triggers, views, buckets, or Supabase Edge Functions changed, verify `docs/supabase_schema.sql` is updated and remains idempotent.
5. **Stay off `main` for initial commit:** If currently on `main` with uncommitted work, create or switch to the user's working branch (or ask) unless the user explicitly asked to commit directly on `main`.

---

## Step 3: Commit Local Work on the Working Branch

1. Stage the verified files:
   - Stage intended modified and untracked files (never blind-stage ignored/secret files).
2. Inspect `git diff --cached --stat` and write a concise Conventional Commit message (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`) matching the repository's history and accurately describing the staged changes.
3. Commit on `<branch>`:

```powershell
git commit -m "<subject>" -m "<optional bullet body>"
```

---

## Step 4: Merge Latest Updates & Resolve Conflicts

1. Merge `origin/main` into `<branch>`:

```powershell
git merge origin/main --no-edit
```

2. If the user approved integrating an unmerged teammate branch (e.g. `origin/YH`), merge it now:

```powershell
git merge origin/<teammate> --no-edit
```

3. **Conflict Resolution Rules:**
   - **Stop and ask user on conflict:** If any merge conflict occurs, or if any step is confusing or ambiguous, **DO NOT guess or auto-resolve**. **STOP immediately** and ask the user how to proceed, clearly showing the conflicted files and the conflicting regions.
   - **Never** run `git checkout --ours` or `--theirs` blindly on shared code files.
   - When the user directs how to resolve the conflicts (or asks to review together), inspect every conflicted file (`git diff --name-only --diff-filter=U`) and verify that neither local features nor teammate changes are accidentally lost.
   - After resolving conflict markers with user agreement, stage the resolved files and complete the merge commit (`git commit --no-edit`).

---

## Step 5: Verify Build, Static Analysis & Tests

After all merges and conflict resolutions are finished, run verification before pushing to `main`:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

- If `flutter analyze` has errors or tests fail:
  - Investigate and fix any analyzer errors or test failures introduced by the merge or your local changes, then re-run `flutter analyze --no-pub` and `flutter test --no-pub`.
  - **Do NOT push broken code to `main`.**
  - However, if `flutter analyze --no-pub` passes cleanly and **all failures are strictly pre-existing unrelated or live-backend environment failures** (verified unchanged from before your changes/merge), proceed with pushing `<branch>` and `main` so the workflow completes in one pass, and clearly list those pre-existing failures in the final report.

---

## Step 6: Push Working Branch & Update `main`

1. Push the updated working branch first:

```powershell
git push origin <branch>
```

2. Update local `main`, merge `<branch>`, and push `main`:

```powershell
git checkout main
git pull --ff-only origin main
git merge <branch> --no-edit
git push origin main
```

3. Switch back to `<branch>` so the user remains on their working branch:

```powershell
git checkout <branch>
```

4. **If `origin/main` rejects direct push** (for example, GitHub branch protection requiring a Pull Request):
   - Keep `<branch>` pushed on `origin`.
   - Switch back to `<branch>`.
   - If `gh` CLI is installed and authenticated, offer/create a PR; otherwise report the exact GitHub Pull Request / compare URL (`https://github.com/<owner>/<repo>/compare/main...<branch>`).

5. **Final verification & bilingual report:** Run `git status` and `git log --graph --oneline --decorate -n 8 --all`, then present a clear report in **both simple English and Chinese (简体中文)** containing:
   - **Conflict status:** Clearly state whether any merge conflicts happened (or "No conflicts"), which files conflicted, and how each conflict was resolved.
   - **What was done (simple explanation):** Plain-language summary of teammate/main check, any unrelated folders/files removed or restored, the commit hash & message on `<branch>`, and push status for `<branch>` and `main`.
   - **How it was done:** Short step-by-step explanation of the git merge/cleanup/conflict-resolution and verification (`flutter analyze` / `flutter test` exact results).
   - **中文翻译 / Chinese Translation:** Full Simplified Chinese translation of the conflict status, what was done, how it was done, test results, and push status.

## Guardrails

- **Never** run `git push --force` or `git push --force-with-lease` on `main` or shared branches.
- **Never** discard uncommitted work (`git reset --hard`, `git clean -fd`) or delete non-empty ambiguous folders without explicit user confirmation.
- **Never** skip reporting unmerged teammate commits or removed/excluded unrelated folders.

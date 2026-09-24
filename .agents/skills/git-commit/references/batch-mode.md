# Batch mode details

Reference for `git-commit` steps 5, 7, and 9 on the batched path. The gates, options, and ordering stay in SKILL.md; this file holds the checks and diff sources those steps apply.

## Whole-file semantics guard (step 5)

SKILL.md step 5 carries the two triggers inline: a dual-state path in the step-1 `git status --porcelain -z -uall` listing (staged AND unstaged edits on the same file, neither status letter a space or `?`, for example `MM` or `AM`), or step 4 resolved to option (b) (only the currently staged set).

Why it exists: on the batched path nothing is staged until step 9, which runs `git add -- <path>` per batch, whole file, from the working tree. For those paths, batching therefore commits the CURRENT working-tree content instead of the hunks the user staged, and step 9's unstage of out-of-batch paths drops the staged hunks of later batches' paths. The single-commit path keeps the staged hunks exactly, which is why it is the option to pick when that precision matters.

## Per-batch diff sources (step 7)

* **Tracked paths**: `git diff HEAD -- <batch-paths>`.
* **Untracked paths**: `git diff HEAD` does not show them. Read the file directly or use `git diff --no-index /dev/null <path>` (it exits 1 whenever it prints a diff, which is the normal result here, not a failure).
* **Unborn branch** (step 1's `git log` reported no commits): `git diff HEAD` is fatal because `HEAD` resolves to nothing. Draft from `git diff --cached -- <batch-paths>` for staged paths and direct reads for untracked ones instead.

The step-1 size cap applies per batch: a batch whose diff exceeds roughly 400 changed lines is drafted from its `--stat` shape plus targeted per-file reads.

## Why every draft is written in one pass

Writing all drafts before the first confirmation is what keeps the sequence coherent (consistent scopes, no bullet duplicated across two messages, no vague final batch) and lets the user review a complete plan instead of discovering the next message only after the previous commit has landed.

## Staging commands (step 9)

Deleted paths and rename sources go through `git rm -q --cached --ignore-unmatch` because `git add` is fatal once the deletion is staged. The verify uses `--no-renames` so a rename lists both sides, as the step-1 listing does, and the comparison against the batch's path list is line by line.

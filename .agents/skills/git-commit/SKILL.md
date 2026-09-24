---
name: git-commit
description: Stage the user-named paths (or the whole workspace after confirmation), draft a .gitmessage-compliant message inline in chat, get approval, then commit via a `git commit -F -` heredoc. A mixed change set is offered as one commit or an ordered batch plan whose messages are ALL drafted up front, approved in one bulk pass, then committed consecutively. Use for "commit this", "commit <paths>", "make a commit", or landing pending changes. Never writes the message to a file and never adds an AI co-author.
compatibility: Requires git 2.22 or later and a POSIX shell (Git Bash on Windows).
---

# Goal

Take the user's pending workspace from "edited" to "committed" in one guided flow. The draft MUST follow `.gitmessage` at the repo root, stay in concise bullet form, and contain no AI tool, model, agent, or vendor co-author.

# When NOT to use

* Nothing is pending: the skill stops at step 2.
* The user wants the commit published: `git-push`.
* The user wants two branches integrated: `git-merge` (it owns its own merge-commit drafting).

# Procedure

Terms such as choice question, independent reads, invoke, and suggest follow AGENTS.md (Skill authoring); in a non-interactive session every gate ends this skill.

Run every command in this skill in a POSIX shell; the redirections and the step-9 heredoc are POSIX syntax and break under PowerShell.

1. **Gather state.** Run these independent reads:
   * `git rev-parse --show-toplevel` (repo root; confirms a working tree).
   * `git status --porcelain -z -uall | tr '\0' '\n'` (the path listing every later step uses; `references/sensitive-content.md` says why it needs `-uall` and `-z`. Each line is a two-letter status, a space, and the path; a rename or copy (`R`, `C`) is followed by a line holding its source path).
   * `git diff --cached --stat` and `git diff --stat` (staged and unstaged shape summaries).
   * `git diff --cached` (full staged diff, fuel for the draft; see the size cap below).
   * `git diff` (full unstaged diff, fuel if any of it will be staged; same cap).
   * `git branch --show-current` (EMPTY output means detached HEAD; an unborn branch prints its name and is NOT detached).
   * `git log --oneline -10` (style reference and HEAD subject for hook-failure diagnosis; fatal on a zero-commit repo: proceed without it).

   **Size cap on the full-diff reads.** When the two `--stat` summaries total more than roughly 400 changed lines, do NOT pull the full diffs into context: draft from the `--stat` shape plus per-file reads (`git diff --cached -- <path>`) of the most central files, and note at step 8 which files were summarized from stat alone.

2. **Refuse when nothing to commit.** If `git status` shows no staged, unstaged, or untracked entries, STOP and tell the user the tree is clean.

3. **Resolve the workflow variant, then apply its trunk policy. Handle this BEFORE any scope question**, because step 4 assumes the commit may land where HEAD points.

   a. **Resolve the variant.** Read the `Workflow:` line in `.gitmessage`'s "Workflow Variant" section.
      * **Declared** (`git-flow`, `github-flow`, or `trunk-solo`): use it as-is. Do not probe, do not ask.
      * **Absent, or an unrecognized value** (anything other than the three, including the shipped `<not recorded>` placeholder): ask with a choice question which of the three applies, with no option marked recommended and each tradeoff taken from `.gitmessage`'s own descriptions; never guess from history (see Hard rules). Then ask a second `record` / `skip` gate to write the answer onto the `Workflow:` line as an in-place edit. After a **record**, `.gitmessage` is a new pending change: re-run the step-1 gather before step 4 and name `.gitmessage` in the step-4 scope listing, so the user decides whether it rides with this commit (step 5 may give it its own `config` batch). When `.gitmessage` itself is absent, skip the record gate: the answer applies to this session only; suggest copying the template's `.gitmessage` in. Until the user answers, treat the variant as `git-flow`.

   b. **Detached HEAD is a hard stop under every variant.** STOP and go to step 3d.

   c. **Apply the trunk policy for the current branch.**

      | Current branch | `git-flow` | `github-flow` | `trunk-solo` |
      |---|---|---|---|
      | `support/*` | gate | gate | **no gate** |
      | `develop` | gate | does not exist | does not exist |
      | `main` | gate | gate | **no gate** |
      | short-lived branch | no gate | no gate | no gate |

      Match rows ignoring case: on a case-insensitive filesystem a HEAD switched to as `Main` or `Support/x` is that protected branch. This table mirrors `.gitmessage`'s "Protected Branches" section, which is normative; when the two disagree, follow `.gitmessage` and say so.

      **gate** = refuse to commit here without an explicit in-turn opt-in (AGENTS.md): a current-turn reply naming the direct commit and the branch, typed ("yes, commit directly on `<branch>`") or chosen as an option whose label states both. A generic yes or an earlier turn's approval does NOT count. Without it, go to step 3d.

      **no gate** = proceed to step 4. Under `trunk-solo`, committing on `main` is the sanctioned path: do not ask, propose a branch, or editorialize. One advisory exception: when the commit set spans three or more top-level directories, add one line to the step-8 presentation noting it may be worth splitting (step 5 offers batches) or moving to a branch, then proceed either way.

   d. **When the gate fires or HEAD is detached**, do not commit where HEAD points. Land the work on a fresh short-lived branch via steps 3e to 3g. Pending changes carry over untouched; nothing needs stashing.

      **Unborn exception.** When the current branch has zero commits (step 1's `git log` reported no commits yet), the rescue path cannot work (`references/branch-rescue.md` says why). State that this is the repository's first commit and ask a choice question with exactly two options: **commit directly on `<branch>`** (the normal bootstrap move, even under `git-flow`; its label names the action and the branch, so choosing it is the explicit in-turn opt-in), or **abort**. Do NOT invoke `git-branch-create`.

   e. **Infer a sensible branch name** from the step-1 diffs in the repo's naming variant (the `Adopted:` line in `.gitmessage`'s "Branch Naming" section; when it is `<not recorded>` or absent, the dominant variant of existing short-lived branches as in `git-branch-create` step 4, else Variant C). Read `references/branch-rescue.md` for the per-variant name shapes, the `<type>` choice, and the short-desc rules.

   f. **Invoke `git-branch-create`** with the proposed name AND an explicit `base=<current HEAD>` (for example `feature/foo-bot/retry-on-timeout base=develop` when HEAD is `develop`, or the literal `base=HEAD` when detached). That skill owns naming validation and its own confirmation; do not duplicate either here.

   The base MUST be the current HEAD, never a hardcoded `main` or `develop`; `references/branch-rescue.md` explains why any other base stalls both skills.

   g. **After `git-branch-create` returns**, verify with `git branch --show-current` that a short-lived branch is checked out, then re-enter this skill at step 1.

4. **Resolve the commit scope** into a recorded path set. Nothing is staged or unstaged here; step 5 decides when staging happens.
   * **User-named scope in the current turn** ("commit src/foo.py", "commit only what is already staged"): record exactly that set and nothing else.
   * **No scope specified (default: the entire workspace)**: list every pending change (staged, unstaged, and untracked separately) and ask with a choice question whether to (a) commit everything pending, (b) commit only the currently staged set, (c) commit a user-supplied subset of paths, or (d) abort. Option (a) is the recommended default; it records every tracked modification plus each untracked file the user confirms by name. Render the untracked paths as one list: a single reply approving that list, or naming the files to keep from it, confirms each file it covers.
   * **Both staged and unstaged non-empty with no scope said**: same prompt, and surface that a partial stage already exists so the user decides intentionally.

5. **Choose single or batched commits.** With the scope resolved, judge whether the pending set is ONE logical change or several: look for distinct `<type>(<scope>)` pairs per the message spec (for example a `feat` in one package plus an unrelated `fix` elsewhere), or the step-3c advisory case of three or more top-level directories.
   * **Clearly one logical change**: proceed as a single commit; do NOT ask.
   * **Two or more distinguishable changes**: render a proposed partition first (one line per batch: `<n>. <type>(<scope>): <intent> -- <paths>`; every path in exactly one batch, no "misc" bucket), then ask with a choice question:
     * **split as proposed (Recommended)**: continue on the batched path.
     * **single commit**: everything in one commit; continue on the single-commit path.
     * **adjust batches**: the user replies with free-text moves ("merge 1 and 3"); re-render the partition and re-ask.
     * **abort**: STOP. Staging state stays as the user left it.
   * **Whole-file semantics guard.** Before asking, check the step-1 listing; the guard fires when either holds: a path is dual-state, with staged AND unstaged edits on the same file (neither status letter a space or `?`, for example `MM` or `AM`); or step 4 resolved to option (b). When it fires, render a WARNING line naming the affected paths immediately above the question. Choosing **split as proposed** with that warning shown counts as the acknowledgment; when staged-hunk precision matters, **single commit** is the option that preserves it exactly. `references/batch-mode.md` explains the guard.
   * **Stage for the chosen path.** Single commit: stage the recorded set now, so steps 6 to 9 read one staged diff. Option (a) runs `git add -u` plus `git add -- <path>...` for the confirmed untracked files; a named set or option (c) stages its paths as step 9 does and runs `git reset -q HEAD -- <path>...` for staged paths outside the set; option (b) stages nothing. Batched: stage nothing; hold each batch as an explicit path list, and step 9 stages each batch in turn, so nothing is staged or committed while the plan is drafted and reviewed.

6. **Sanity-check sensitive content.** Before drafting, scan the final commit set against the lists below: every path (from the step-1 listing) and its content (the staged diff, or in batched mode each batch's step-7 diff source; untracked files read whole). On any match, STOP and ask for confirmation per file; suggest `.gitignore` additions rather than committing. `references/sensitive-content.md` holds the scan commands and the reasons for each rule.
   * **Filenames**: `.env`, `.env.*` (except `.env.example`, `.env.sample`, `.env.template`), `credentials.*`, `*.pem`, `*.key`, `*_rsa`, `id_rsa*`, `*.keystore`, `*.p12`, `*.pfx`.
   * **Value-shaped content** (extended regex): `-----BEGIN [A-Z ]*PRIVATE KEY-----`, `hf_[A-Za-z0-9]{30,}`, `ghp_[A-Za-z0-9]{36}`, `github_pat_[A-Za-z0-9_]{20,}`, `AKIA[0-9A-Z]{16}`, `xox[baprs]-[A-Za-z0-9-]+`, `eyJ[A-Za-z0-9_-]{20,}` (JWT), ``([Aa][Pp][Ii][_-]?[Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt])[A-Za-z_]*[[:space:]]*[:=][[:space:]]*(['"][^'"$][^'"]{7,}|([^'"[:space:]()<>`$.]{8,}|[^'"[:space:]()<>`$]*[.][^'"[:space:]()<>`$]*[^'"[:space:]()<>`$A-Za-z0-9_.,;][^'"[:space:]()<>`$]*)([[:space:]]|$))`` (an assignment carrying a literal value, any keyword case), `sk-[A-Za-z0-9_-]{20,}`. Bare words like `token` outside such an assignment are NOT matches.
   * **Home paths naming a real user**, on added lines only (the `+` lines of the diff, or every line of an untracked file): `/(home|Users)/[A-Za-z0-9._-]+/` and `[A-Za-z]:[\\]+Users[\\]+[A-Za-z0-9._-]+[\\]`. A `<user>` placeholder, `~/`, `$HOME`, and `%USERPROFILE%` name no user and are NOT matches.

7. **Draft the message(s) inline (no file).** Apply `.gitmessage` (normative) through `references/message-spec.md`, which defers to it on any conflict and applies alone when it is absent.
   * **Single commit**: one draft from the final staged diff (refresh `git diff --cached` if step 5 staged anything) and the recent log from step 1.
   * **Batched**: draft EVERY batch's message NOW, one per batch, each from its batch's diff, before any confirmation or commit. Read `references/batch-mode.md` for the diff source per path (tracked, untracked, unborn branch) and the per-batch size cap.

   Hold the draft(s) in chat as fenced code blocks, labeled by batch number in batched mode.

8. **Show and confirm.**
   * **Single commit**: display the draft inline as a fenced code block, then ask with a choice question (as a preview when supported): **approve** / **edit** / **abort**.
     * **approve**: proceed to step 9 with the current draft.
     * **edit**: the user replies with free-text edits (for example "add `Refs #42`", or a complete replacement). Apply them, re-render the draft, and re-ask until approved or aborted.
     * **abort**: stop. The staged set stays as is.
   * **Batched**: render the complete plan once (every batch with its path list and full draft), then collect ALL batch decisions BEFORE committing anything:
     * **Collect decisions in bulk.** Ask each batch's decision as a choice question, packing as many into one prompt as the interface allows; each shows that batch's draft and path list (as a preview when supported). Options per batch: **commit** / **edit** / **skip**. Aborting the whole sequence is always available as a typed reply on any question; nothing has committed yet at this point.
     * **edit**: apply the free-text edits to that batch's message, or move a path between two batches (re-rendering both drafts). Re-ask ONLY the edited batches (bulk again when several); decided batches keep their answers.
     * **Execute once decisions are final.** Run step 9 for every commit-marked batch consecutively, in plan order, with NO prompts in between. **skip** batches stay pending and uncommitted. On any failure, stop the run per step 10 and report which batches landed and which remain.

9. **Commit via heredoc, no file.** In batched mode, run this step once per approved batch, in plan order with no prompts in between: first unstage anything staged that is outside the batch (`git reset -q HEAD -- <path>...`), stage exactly the batch (`git add -- <path>...` for paths present in the working tree, untracked ones only after their step-4 confirmation; `git rm -q --cached --ignore-unmatch -- <path>...` for deleted paths and rename sources; `references/batch-mode.md` says why), and verify `git diff --cached --name-only --no-renames -z | tr '\0' '\n'` lists exactly the batch's paths, line by line. Pipe the approved message to `git commit -F -` through a quoted heredoc, which blocks shell expansion:
   ```
   git commit -F - <<'COMMIT_MSG_EOF'
   <type>(<scope>): <subject>

   - bullet 1
   - bullet 2
   COMMIT_MSG_EOF
   ```
   Substitute the approved draft verbatim, preserving the blank line between header and body. If the draft contains a line equal to `COMMIT_MSG_EOF`, pick a fresh terminator absent from the body. Capture the exit code and full output.

   **Post-commit check**, after every successful commit (each batch in batched mode): record `pre=$(git diff --cached --name-only --no-renames -z | tr '\0' '\n')` right before `git commit`, then compare it with `post` from `base=$(git rev-parse -q --verify HEAD^1 || git hash-object -t tree /dev/null) && post=$(git diff-tree --name-only -r -z --no-renames "$base" HEAD | tr '\0' '\n')`. A hook that stages or unstages files makes them differ: STOP, run no later batch, never amend or reset, run the step-6 scan on each extra path, and report the extra and missing paths verbatim plus any scan hit. Read `references/post-commit-check.md` for the commands.

10. **Handle hook failure.** If a pre-commit, prepare-commit-msg, or commit-msg hook blocked the commit:
    * The commit did NOT happen; the previous commit at HEAD is unchanged.
    * Surface the hook's exact output.
    * STOP. In batched mode the whole sequence stops: report which batches landed (with SHAs) and which remain. Help fix the underlying issue, then re-run this skill from step 1; the drafts stay in the conversation and may be approved again unchanged.

11. **Report success.** Show the new commit SHA and subject (`git log -1 --format='%h %s'`); in batched mode, one `<sha> <subject>` line per landed batch in order, plus any batch that was skipped. Then the branch it landed on with the active workflow variant in parentheses (for example `main (trunk-solo)`), `git -c core.quotePath=false status --short -uall` for anything still pending, and the natural next step (usually `git-push`, or another `git-commit` for the remainder).

# References

Paths are relative to this skill's directory (repo path `.agents/skills/git-commit/`).

* `references/message-spec.md`: step 7 ("Standard commit message" section; shared with `git-merge`).
* `references/branch-rescue.md`: steps 3b to 3f.
* `references/sensitive-content.md`: step 6.
* `references/batch-mode.md`: steps 5, 7, and 9.
* `references/post-commit-check.md`: step 9.

# Hard rules

* NEVER write the commit message to a file on disk (no scratch file, no `.git/COMMIT_EDITMSG` pre-population). It lives only in the chat and the heredoc that feeds `git commit -F -`.
* NEVER stage files with `git add .` or `git add -A`, and never use a path glob that could pick up untracked files. `git add -u` is permitted ONLY for the tracked-modification bulk-stage of step 4 option (a) on the single-commit path (step 5); stage untracked files by explicit name after the step-4 confirmation.
* NEVER pass `--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=false`, `--amend`, or `--allow-empty` without an explicit in-turn opt-in naming that flag; a generic yes does not count. Hooks fail for a reason; fix the underlying issue.
* NEVER `--amend` after a hook failure: the failed commit never landed, so `--amend` would rewrite the PREVIOUS commit. Create a new commit instead.
* NEVER commit files matching the step-6 sensitive-content lists without per-file user confirmation.
* NEVER draft batch messages lazily. Every batch message is written in step 7 before the first batch is confirmed.
* NEVER amend, reorder, or otherwise reopen an already-committed batch; edits apply only to batches not yet committed. After a step-9 post-commit mismatch, never amend, reset, or continue.
* NEVER interleave approval and execution in batched mode. Collect every batch's decision first (step 8), then commit the approved batches consecutively.
* NEVER commit onto a detached HEAD under any workflow variant.
* NEVER commit on a branch the active variant protects, compared ignoring case, without an explicit in-turn opt-in. The protected set comes from `.gitmessage`'s "Workflow Variant" section, never from a hardcoded list in this file.
* NEVER assume a permissive variant. When `.gitmessage` declares no `Workflow:` line, or the line carries an unrecognized value (such as the shipped `<not recorded>` placeholder), treat the repo as `git-flow` (the strictest) until the user answers, and record the answer in `.gitmessage`, not in memory.
* NEVER infer the workflow variant from history shape: squash and rebase merges make a PR-reviewed repo and a direct-commit trunk look identical. Ask the user.
* NEVER re-propose a branch on `main` under `trunk-solo` beyond the single advisory line in step 3c; committing on the trunk is that variant's sanctioned path.
* NEVER add any AI tool, model, agent, or vendor attribution: no `Co-Authored-By:` trailer naming an assistant or its vendor, and no `Generated with <tool>` line. Do not invent co-authors.
* NEVER include credentials, API keys, or absolute home paths (`/home/<user>/`, `C:\Users\<user>\`) in the body. Use repo-relative paths only.
* If `git commit -F -` fails for any reason other than a hook (a corrupt index, a missing GPG key), surface the error verbatim and stop. Do not invent a workaround.

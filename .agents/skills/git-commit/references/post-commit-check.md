# Post-commit path check

Reference for `git-commit` step 9: the commands behind the post-commit check and why it exists. The STOP, the scan of extra paths, and the ban on amend, reset, and later batches stay in SKILL.md.

## Why it exists

A `pre-commit` or `prepare-commit-msg` hook runs after the skill last reads the index and may still `git add` or `git reset` paths; git commits the index as the hook leaves it. The commit then holds files that were never scanned at step 6 or approved at step 8, or lacks files that were. Only the landed commit shows what happened, so the check reads it back.

## Commands

Right before `git commit`, record the approved set as git lists it:

```sh
pre=$(git diff --cached --name-only --no-renames -z | tr '\0' '\n')
```

After the commit succeeds, read the paths it recorded:

```sh
base=$(git rev-parse -q --verify HEAD^1 || git hash-object -t tree /dev/null) &&
post=$(git diff-tree --name-only -r -z --no-renames "$base" HEAD | tr '\0' '\n')
[ "$pre" = "$post" ]
```

* Two explicit trees are required. Given only `HEAD`, `diff-tree` prints nothing for a merge commit (concluding a merge would report every path as missing, and a path a hook added would go unseen), and nothing for a repository's first commit unless `--root` is passed. Diffing against the first parent matches what `git diff --cached` compared the index with before the commit, merge or not. A first commit has no `HEAD^1`, so `base` falls back to the empty tree, whose ID `git hash-object -t tree /dev/null` prints without writing any object.
* `--no-renames` lists both sides of a rename, matching the staged list.
* Both commands print paths in the same order, so plain string equality is the test.

On a mismatch, list the differences verbatim:

```sh
printf '%s\n' "$post" | grep -vxF -e "$pre"   # extra: committed, not approved
printf '%s\n' "$pre" | grep -vxF -e "$post"   # missing: approved, not committed
```

`grep -e` takes the newline-separated list as one pattern per line. When one side is empty, `grep -e ""` matches every line and prints nothing, so report the whole other side instead. All of the above runs unchanged under bash and dash.

## Scanning extra paths

Run the step-6 checks on each extra path: the filename list on its name, and the value and home-path patterns on the lines the commit added:

```sh
git diff-tree -p "$base" HEAD -- "$p" | grep -E '^[+]' | grep -vE '^[+]{3} ' | grep -nE -e "$VALUE_RE"
```

and the same pipeline with `"$HOME_RE"` (`base` from the check above; both variables as `references/sensitive-content.md` defines them). Include every hit in the report; the commit already exists, so the user decides how to undo it.

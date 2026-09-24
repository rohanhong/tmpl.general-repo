# Rationale

Reference for `hf-upload`. The procedure, gates, and hard rules live in SKILL.md; this file holds the reasons behind them and the limits of the pre-gate checks.

## Design

* **`create_commit` over CLI or git push**: it is the only path that applies N>1 files atomically, accepts delete and rename ops, and returns the commit SHA directly.
* **The gate is per-operation, not per-invocation**: a wrong `path_in_repo` on a replace does not fail, it silently creates a duplicate file, so the rendered op list is the only place that mistake is catchable before it lands. The step-2 listing flags that case as `ABSENT`.

## Path resolution (step 2)

* **Folder deletes are expanded.** `CommitOperationDelete(path_in_repo="weights/")` sets `is_folder=True` and deletes everything under that prefix, while the gate would show one line. Expanding it to the concrete files at the listed revision and sending one delete per file makes the gate show exactly what is removed, and a file added to the folder after the listing is left alone.
* **Root-reaching paths are rejected before the library sees them.** `huggingface_hub` strips a leading `/` and `./` and rejects only `.`, `..`, a `../` prefix, and `.git` segments, so `/` or `./` becomes an empty path that it does not reject. The skill therefore rejects empty paths, `/`, `.`, any empty, `.`, or `..` segment (which also covers `//` and a leading `/`), and backslashes (usually a mistyped Windows separator).
* **Existing targets are marked `REPLACE`.** An add, a copy, or the new path of a rename onto an existing `path_in_repo` overwrites that file with no error; the listing is the only place to see it before it lands.
* **`parent_commit` pins the listing.** The listing is taken at the branch head `sha`; passing that `sha` as `parent_commit` makes `create_commit` fail if the branch moved, so the expansions and `REPLACE` marks the user approved cannot go stale.

## Sensitive-content scan (step 5)

* **Why scan at all.** A public repo is readable by anyone the moment the commit lands, and Hub history keeps a file after a later delete, so a leaked key has to be rotated, not just removed.
* **Shared lists.** The filename list and regexes come from `git-commit` so both skills flag the same things; `hf-upload` has no staged diff, so every line of each local file counts as added.
* **Binary detection.** A NUL byte in the first 64 KiB marks a file as binary (weights in `.pt`, `.safetensors`, `.onnx`, and `.gguf` files contain NULs near the start), which avoids grepping multi-GB weights. Limits: a UTF-16 text file also counts as binary and is not scanned, and a binary file without an early NUL is grepped, where any match still stops the flow.
* **Line numbers only.** The scan prints file and line numbers, never the matched text, so a real secret is not copied into the chat transcript.

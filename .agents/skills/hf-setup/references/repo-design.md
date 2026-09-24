# Phases 2, 3, and 5a: Owner, repo design, and layout details

Loaded from `hf-setup/SKILL.md` Phase 2, Phase 3, and Phase 5a. Read this file when building the Phase 2 owner question, the Phase 3b to 3e choice questions, and the Phase 5a layout question, and before rendering the Phase 3f create step. The Hard rules in `SKILL.md` remain in force throughout, and the Phase 3f **create** / **abort** gate stays in `SKILL.md`.

## 2. Owner options

* **Personal account `<username>`**: simpler, fewer concepts. Right for solo experiments, scratch work, single-maintainer projects.
* **Existing organization `<org-name>`**: project-level ownership, multi-admin, survives personnel changes, separate quota pool. Right for team projects with a shared GitHub repo.
* **Create new organization**: when the project has a stable identity and likely more than one contributor over its lifetime. The user creates it at `https://huggingface.co/organizations/new`; wait for confirmation, then, when logged in, re-run the probe 3 command to verify membership (logged out, Phase 4c verifies it).

Org naming heuristic: derive from the project or company name. If the consuming code repo is `acme/foo-bot`, suggest org `acme` or `foo-bot-team`. Lowercase, hyphens. Confirm with the user; do not auto-create.

## 3b. Repo types

Repo type is set at creation and immutable afterward. The HF "New" menu shows several entries; only some are storage:

| Entry | Use for | Notes |
|---|---|---|
| **Model** | ML weights (`.pt`, `.bin`, `.safetensors`, `.onnx`, `.gguf`, `.ckpt`) | Default `.gitattributes` already LFS-tracks ML extensions; visible in model search; supports inference widget metadata. Default for ML weights. |
| **Dataset** | Training data, evaluation sets, labeled corpora | Different default `.gitattributes` tuned for data formats; surfaces in dataset search. |
| **Space** | Runnable Gradio or Streamlit demos | A hosted app runtime, not static storage. Not offered. |
| **Bucket** | Generic large-blob storage without git semantics | Object-storage style; no commit history, so no SHA pin, no `create_commit` upload, and no Phase 6. Not offered; see When NOT to use in `SKILL.md`. |
| Article, Collection, Access Token | Not storage | Article = blog post; Collection = grouping pointer; Access Token opens the token settings. Skip. |

Binary weights or checkpoints: **Model**. Training data, rosbags, large CSVs: **Dataset**. The Phase 3b question offers only these two.

## 3c. Naming conventions

Collapse the Phase 1 Q5 module list into a `<scope>` reflecting which modules the repo will host. Combine with the consuming repo's package layout when those names diverge (rare but possible).

Convention `<scope>-<purpose>`:

* `<owner>/<project>-models`: all models for one project in one repo. Fits when Q5 listed one module or the user wants a single combined repo.
* `<owner>/<project>-<module>-models`: per-module split when Q5 listed two or more modules and Q4 said "fresh sibling in an existing family" (`acme/foo-bot-perception-models`, `acme/foo-bot-arm-models`).
* `<owner>/<project>-<dataset>-data`: for datasets.

Naming character rules: lowercase ASCII letters, digits, and `-` only. No underscores (HF convention; some tools confuse `_` with separators). Stay well under 96 chars.

## 3d. License options

* **Apache-2.0** (default for ML model weights): de facto standard; the explicit patent grant and reciprocal-termination clause matter when artifacts end up in commercial products, and a private repo may flip public later.
* **MIT** when the user has a repo-wide MIT convention and prefers it. Shorter, broadly compatible, no patent grant.
* **CC-BY-4.0** for datasets (de facto standard for data sharing).
* **Other** (CC-BY-NC, OpenRAIL, custom) only on explicit request. These have known compatibility quirks with commercial or downstream-fine-tune use; flag the quirk before the user picks.

## 3e. Visibility options

* **Public**: anyone can `hf_hub_download` without auth. Best for community models, published research weights, open datasets.
* **Private**: requires authenticated download. Free private storage is 100 GB per account or org (as of this writing; verify the current quota at `https://huggingface.co/pricing` before planning around it). Default for proprietary, pre-release, or sensitive artifacts. Every consuming machine (CI, robots, teammates) will need a read token, which becomes Phase 4 and Phase 6e work.

## 3f. Creation details

Web UI is easier the first time (visual confirmation, license dropdown, type descriptions); the user clicks through `https://huggingface.co/new` and confirms back in the conversation.

`hf repos` and `hf repo` are aliases for the same command group and both work; prefer the plural for consistency with the rest of this skill. Do not tell the user the singular is deprecated: current releases print identical help for both with no deprecation notice.

A created repo occupies the owner's namespace under that name, and even immediate deletion leaves the slug reserved for a cooldown window, so a wrong name costs more than the bandwidth of the first push.

After creation, confirm at `https://huggingface.co/<owner>/<name>`; the auto-generated `.gitattributes` and `README.md` should be there.

The CLI path sets NO license: `hf repos create` has no license flag, so the Phase 3d choice must be applied afterwards by adding `license: <id>` to the YAML metadata block at the top of the repo's `README.md` (web UI "Edit model card", or a follow-up `hf-upload` commit). The web UI create form sets it directly via its license dropdown.

## 5a. In-repo layout

* **Flat** (`<repo>/<filename>`): simplest, right when the repo holds one logical artifact class.
* **Subdirs** (`<repo>/<group>/<filename>`): when one repo holds multiple categories (`perception/`, `arm/`, `voice/`). Group by what the consuming code calls the artifact, not by file format.

If the consuming code expects flat on-disk paths (common for ROS, CLI tools, training scripts) but subdirs are clearer on HF, the Phase 6 downloader flattens by basename. Document the choice in the manifest so future readers do not confuse the two layouts.

**Basename collision warning**: with subdirs on HF, no two artifacts may share a basename across subdirs, or the basename-flatten would silently overwrite the loser. The `hf-download` reference script includes a collision check up front; rely on it.

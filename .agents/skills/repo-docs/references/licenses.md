# Licenses

Loaded from `repo-docs/SKILL.md` at the license step. This is guidance for picking and writing the file, not legal advice; say so when the user asks which license is right for a commercial or legal situation.

## Choosing

| SPDX id | In one line |
|---|---|
| `MIT` | Short and permissive; keep the notice. The common default for open source. |
| `Apache-2.0` | Permissive with an explicit patent grant and patent-retaliation clause; changes must be marked; NOTICE files carried along. |
| `BSD-3-Clause` | Permissive like MIT, plus no use of the holder's name for endorsement. |
| `MPL-2.0` | File-level copyleft: changed files stay open, the larger work may be closed. |
| `GPL-3.0-only` / `GPL-3.0-or-later` | Strong copyleft: distributed derivatives must be GPL with source. |
| `AGPL-3.0-only` / `AGPL-3.0-or-later` | GPL plus network use: offering it as a service triggers source sharing. |
| `Unlicense` | Public-domain dedication; no conditions. |
| Proprietary | All rights reserved; no rights granted without a separate agreement. Not open source. |

Other licenses the user names are fine when choosealicense.com carries them (`BSD-2-Clause`, `ISC`, `LGPL-2.1-only`, `LGPL-3.0-or-later`, `BSL-1.0`, `EPL-2.0`, `0BSD`, `CC0-1.0`, `MulanPSL-2.0`, and more). Use current SPDX ids; the bare `GPL-3.0`, `LGPL-2.1`, and similar forms are deprecated.

## Writing an open-source license

Fetch the canonical text; never write it from memory. GitHub identifies a license by exact text, so a paraphrase shows as "Other" in the repository sidebar and license tab.

Map the SPDX id to the choosealicense file key: lowercase it, and for the GNU family (`GPL`, `LGPL`, `AGPL`) drop the `-only` or `-or-later` suffix (`GPL-3.0-or-later` becomes `gpl-3.0`, `LGPL-2.1-only` becomes `lgpl-2.1`). Both suffixes share one license text; the choice between them is recorded in the README Legal line and the file notices, not in `LICENSE`, and the License badge uses the static form with the full SPDX id (`badge/license-GPL--3.0--or--later-blue`), because the dynamic GitHub badge cannot show the suffix.

```sh
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; D="${TMPDIR:-/tmp}/repo-docs-$(printf %s "$ROOT" | cksum | cut -d' ' -f1)"
key=<file key, for example apache-2.0>; out=<LICENSE, or COPYING for the GPL text of an LGPL project>
rm -f "${D:?}/$out" "${D:?}/$out.src" &&
  curl -fsSL -o "$D/$out.src" "https://raw.githubusercontent.com/github/choosealicense.com/gh-pages/_licenses/$key.txt" &&
  awk 'n >= 2 { print; next } /^---$/ { n++ }' "$D/$out.src" | sed '1{/^$/d;}' > "$D/$out" &&
  [ -s "$D/$out" ] && rm -f "${D:?}/$out.src" && echo "fetched $key as $out"
```

Step 8 of `SKILL.md` has already emptied `$D`; the `rm -f` also clears a file this run fetched before, so a retry never reuses it.

The source file starts with YAML front matter between two `---` lines; the `awk` keeps only the text after it. Downloading to a file first makes a failed or cut-off transfer end the chain with curl's non-zero status. Without the `fetched` line, report it and stop; do not fall back to a remembered text. Otherwise:

* Fill the notice placeholders: `[year]` and `[fullname]` with the year and holder settled below. This applies to MIT, BSD, ISC, and the other short permissive texts.
* Leave the appendix placeholders of Apache-2.0 (`[yyyy]`, `[name of copyright owner]`) and the GNU family (`<year>`, `<name of author>`, `<program>`) unchanged: they belong to the "how to apply" instructions, and editing them breaks license detection.
* MPL-2.0 and the Unlicense have no placeholders.
* LGPL is a set of additional permissions on top of the GPL, so an LGPL project ships both texts: the LGPL text as `LICENSE` and the matching GPL text (`gpl-3.0` for LGPL-3.0, `gpl-2.0` for LGPL-2.1) as `COPYING`, fetched with `out=COPYING`.
* Step 11 moves `$D/LICENSE` (and `$D/COPYING`) into place; nothing is written to the repository before that.

Apache-2.0 projects may add a `NOTICE` file (`<Project Name>` plus `Copyright <year> <holder>`); offer it, never require it.

## Holder and year

* **Residue LICENSE** (a template copy; see `SKILL.md` step 2): the template author's copyright line is replaced. The holder defaults to `git config user.name`, which the user confirms or corrects; the year is the current year.
* **A project's own LICENSE**: keep its holder and first year. Adding a holder or extending the year range (`2024-2026`) is an ordinary gated edit; removing or replacing another holder needs an explicit in-turn opt-in naming the old and new line, because it rewrites someone else's copyright notice.
* **New LICENSE**: the holder defaults to `git config user.name`, confirmed by the user; the year is the current year.

## Proprietary

Use this text, filling `<year>` and `<holder>`:

```text
Copyright (c) <year> <holder>. All rights reserved.

This software and its associated documentation (the "Software") are
proprietary and confidential. No license, express or implied, is granted to
any person to use, copy, modify, merge, publish, distribute, sublicense, or
sell the Software, in whole or in part, except under a separate written
agreement with the copyright holder.

Unauthorized copying of the Software, by any means, is strictly prohibited.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

A proprietary repository usually drops the Contributing section's open invitation and the Code of Conduct; ask rather than assume. Its README license badge is the static form `badge/license-Proprietary-red`, and its README omits Star History.

## Changing an existing license

A residue LICENSE is not the project's license yet, so replacing it is an ordinary gated choice. Any other existing LICENSE is the project's: relicensing needs the consent of every copyright holder, and earlier releases stay under their old license. Changing it requires an explicit in-turn opt-in that names the old and new license; mention the consent issue in the question. Code received under Apache-2.0 or another license keeps that license and its notices (including `NOTICE`) even when the project turns proprietary; say so when the old license is a permissive or copyleft one and the new one is proprietary.

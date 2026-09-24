#!/bin/sh
# Render a line of text as a pixel-font SVG banner for a README header.
#
# Usage:
#   sh pixel-banner.sh --text TEXT --out FILE [--from COLOR] [--to COLOR]
#                      [--pixel N] [--animate]
#
#   --text     Text to draw: letters (drawn uppercase), digits, space, and
#              . - _ / : ! ? (at least one letter or digit).
#   --out      Output SVG path; its directory must exist.
#   --from     Gradient start color, #rgb or #rrggbb (default #0969da).
#   --to       Gradient end color, #rgb or #rrggbb (default #8250df).
#   --pixel    Size of one pixel cell in SVG units, at least 2 (default 10).
#   --animate  Type the text in letter by letter, hold, then clear, on a
#              loop, with a blinking cursor. Viewers who ask for reduced
#              motion see the static banner.
#
# Defaults may also come from the environment: PIXEL_BANNER_FROM,
# PIXEL_BANNER_TO, PIXEL_BANNER_PIXEL. Options win over the environment.
# For a light and a dark variant, run it twice with different colors.
#
# Exit status: 0 on success, 2 for a usage or output error, 3 when --text
# holds no letter or digit or an unsupported character.

set -eu
# Byte-wise character classes, so [A-Za-z] never matches non-ASCII letters.
LC_ALL=C
export LC_ALL

text=
out=
from=${PIXEL_BANNER_FROM:-#0969da}
to=${PIXEL_BANNER_TO:-#8250df}
pixel=${PIXEL_BANNER_PIXEL:-10}
animate=0

die() { printf 'pixel-banner: %s\n' "$1" >&2; exit 2; }
# Print the header comment (line 2 up to the first line not starting with #).
usage() { sed -n '2,${/^#/!q;s/^# \{0,1\}//;p;}' "$0"; }

[ $# -gt 0 ] || { usage; exit 0; }

while [ $# -gt 0 ]; do
  case "$1" in
    --text) [ $# -ge 2 ] || die "--text needs a value"; text=$2; shift 2 ;;
    --out) [ $# -ge 2 ] || die "--out needs a value"; out=$2; shift 2 ;;
    --from) [ $# -ge 2 ] || die "--from needs a value"; from=$2; shift 2 ;;
    --to) [ $# -ge 2 ] || die "--to needs a value"; to=$2; shift 2 ;;
    --pixel) [ $# -ge 2 ] || die "--pixel needs a value"; pixel=$2; shift 2 ;;
    --animate) animate=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$text" ] || die "--text is required"
[ -n "$out" ] || die "--out is required"
case "$text" in *[!A-Za-z0-9\ ._/:!?-]*) printf 'pixel-banner: unsupported character in --text: %s
' "$text" >&2; exit 3 ;; esac
case "$text" in *[A-Za-z0-9]*) ;; *) printf 'pixel-banner: --text needs a letter or digit
' >&2; exit 3 ;; esac
[ -d "$(dirname "$out")" ] || die "output directory does not exist: $(dirname "$out")"
for c in "$from" "$to"; do
  printf '%s\n' "$c" | grep -Eq '^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$' || die "not a hex color: $c"
done
case "$pixel" in ''|*[!0-9]*) die "--pixel must be a positive integer" ;; esac
[ "$pixel" -ge 2 ] || die "--pixel must be at least 2"

awk -v text="$text" -v from="$from" -v to="$to" -v px="$pixel" -v animate="$animate" '
function glyph(ch, rows) { font[ch] = rows }
BEGIN {
  glyph("A", ".###. #...# #...# ##### #...# #...# #...#")
  glyph("B", "####. #...# #...# ####. #...# #...# ####.")
  glyph("C", ".###. #...# #.... #.... #.... #...# .###.")
  glyph("D", "####. #...# #...# #...# #...# #...# ####.")
  glyph("E", "##### #.... #.... ####. #.... #.... #####")
  glyph("F", "##### #.... #.... ####. #.... #.... #....")
  glyph("G", ".###. #...# #.... #.### #...# #...# .####")
  glyph("H", "#...# #...# #...# ##### #...# #...# #...#")
  glyph("I", ".###. ..#.. ..#.. ..#.. ..#.. ..#.. .###.")
  glyph("J", "..### ...#. ...#. ...#. ...#. #..#. .##..")
  glyph("K", "#...# #..#. #.#.. ##... #.#.. #..#. #...#")
  glyph("L", "#.... #.... #.... #.... #.... #.... #####")
  glyph("M", "#...# ##.## #.#.# #.#.# #...# #...# #...#")
  glyph("N", "#...# #...# ##..# #.#.# #..## #...# #...#")
  glyph("O", ".###. #...# #...# #...# #...# #...# .###.")
  glyph("P", "####. #...# #...# ####. #.... #.... #....")
  glyph("Q", ".###. #...# #...# #...# #.#.# #..#. .##.#")
  glyph("R", "####. #...# #...# ####. #.#.. #..#. #...#")
  glyph("S", ".#### #.... #.... .###. ....# ....# ####.")
  glyph("T", "##### ..#.. ..#.. ..#.. ..#.. ..#.. ..#..")
  glyph("U", "#...# #...# #...# #...# #...# #...# .###.")
  glyph("V", "#...# #...# #...# #...# #...# .#.#. ..#..")
  glyph("W", "#...# #...# #...# #.#.# #.#.# #.#.# .#.#.")
  glyph("X", "#...# #...# .#.#. ..#.. .#.#. #...# #...#")
  glyph("Y", "#...# #...# .#.#. ..#.. ..#.. ..#.. ..#..")
  glyph("Z", "##### ....# ...#. ..#.. .#... #.... #####")
  glyph("0", ".###. #...# #..## #.#.# ##..# #...# .###.")
  glyph("1", "..#.. .##.. ..#.. ..#.. ..#.. ..#.. .###.")
  glyph("2", ".###. #...# ....# ...#. ..#.. .#... #####")
  glyph("3", "##### ...#. ..#.. ...#. ....# #...# .###.")
  glyph("4", "...#. ..##. .#.#. #..#. ##### ...#. ...#.")
  glyph("5", "##### #.... ####. ....# ....# #...# .###.")
  glyph("6", "..##. .#... #.... ####. #...# #...# .###.")
  glyph("7", "##### ....# ...#. ..#.. .#... .#... .#...")
  glyph("8", ".###. #...# #...# .###. #...# #...# .###.")
  glyph("9", ".###. #...# #...# .#### ....# ...#. .##..")
  glyph(" ", "..... ..... ..... ..... ..... ..... .....")
  glyph(".", "..... ..... ..... ..... ..... .##.. .##..")
  glyph("-", "..... ..... ..... .###. ..... ..... .....")
  glyph("_", "..... ..... ..... ..... ..... ..... #####")
  glyph("/", "....# ....# ...#. ..#.. .#... #.... #....")
  glyph(":", "..... .##.. .##.. ..... .##.. .##.. .....")
  glyph("!", "..#.. ..#.. ..#.. ..#.. ..#.. ..... ..#..")
  glyph("?", ".###. #...# ....# ...#. ..#.. ..... ..#..")

  s = toupper(text); n = length(s)
  # Layout in pixel cells: 1-cell margin, 5-cell glyphs, 1-cell spacing,
  # a bottom row for the shadow; the animated variant adds a cursor cell.
  cols = 1 + n * 6 + 1 + (animate ? 6 : 0)
  rows = 1 + 7 + 2
  w = cols * px; h = rows * px; dot = px - 1
  shade = (px >= 6) ? int(px / 6) : 1

  printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" role=\"img\" aria-label=\"%s\">\n", w, h, w, h, text
  printf "<title>%s</title>\n", text
  printf "<defs><linearGradient id=\"g\" x1=\"0\" y1=\"0\" x2=\"%d\" y2=\"0\" gradientUnits=\"userSpaceOnUse\">", w
  printf "<stop offset=\"0\" stop-color=\"%s\"/><stop offset=\"1\" stop-color=\"%s\"/></linearGradient></defs>\n", from, to
  if (animate) {
    step = 0.12; cycle = n * step + 4
    printf "<style>\n"
    printf ".c{animation:t %.2fs linear infinite both}\n", cycle
    printf "@keyframes t{0%%{opacity:0}%.2f%%{opacity:1}85%%{opacity:1}88%%{opacity:0}100%%{opacity:0}}\n", 100 * step / cycle
    printf ".k{animation:b 1s steps(1) infinite}\n"
    printf "@keyframes b{50%%{opacity:0}}\n"
    printf "@media (prefers-reduced-motion:reduce){.c,.k{animation:none}}\n"
    printf "</style>\n"
  }

  for (i = 1; i <= n; i++) {
    ch = substr(s, i, 1); split(font[ch], r, " ")
    d = ""
    for (y = 1; y <= 7; y++) for (x = 1; x <= 5; x++) if (substr(r[y], x, 1) == "#") {
      d = d sprintf("M%d %dh%dv%dh-%dz", (1 + (i - 1) * 6 + x - 1) * px, y * px, dot, dot, dot)
    }
    if (d == "") continue
    if (animate) printf "<g class=\"c\" style=\"animation-delay:%.2fs\">", (i - 1) * step
    else printf "<g>"
    printf "<path fill=\"url(#g)\" opacity=\".3\" transform=\"translate(%d %d)\" d=\"%s\"/>", shade * 2, shade * 2, d
    printf "<path fill=\"url(#g)\" d=\"%s\"/></g>\n", d
  }
  if (animate) {
    printf "<rect class=\"k\" x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"%s\"/>\n", (1 + n * 6) * px, 7 * px, 5 * px - 1, dot, to
  }
  printf "</svg>\n"
}' > "$out.tmp" && mv "$out.tmp" "$out" || { rm -f "$out.tmp"; die "could not write $out"; }

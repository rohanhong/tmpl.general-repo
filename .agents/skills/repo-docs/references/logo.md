# Header image options

Loaded from `repo-docs/SKILL.md` at the header-image step. Header images live in `.github/assets/`; the README shows them through the `<picture>` block in `layout.md`, with a light and a dark variant where the image depends on the background.

| Option | Files | Best for | Tradeoff |
|---|---|---|---|
| Static pixel text | `banner-light.svg`, `banner-dark.svg` | Most repositories; no design work | Text only, no symbol |
| Animated pixel text | same names, generated with `--animate` | A playful or showcase project | Animation plays on github.com in browsers; renderers that run CSS but freeze at time zero may show a blank or partial frame |
| Logo prompt | `logo.png` (optionally `logo-dark.png`), made by the user | A project that wants a real symbol | Needs an external image generator and a follow-up step |
| Custom | the user's file, copied in, or a URL | An existing brand | None |
| None | nothing | Small internal repositories | A plainer header |

## Pixel text

`scripts/pixel-banner.sh` (in this skill) draws the text in a 5x7 pixel font with a left-to-right color gradient and a soft offset shadow; run it with no arguments for its usage. The text is usually the repository name (letters come out uppercase); keep it under about 24 characters so the banner stays legible at README width. The README sets `width="640"`; lower it for short text.

Palettes (light variant first, dark variant brighter for dark backgrounds):

| Palette | Light `--from` / `--to` | Dark `--from` / `--to` |
|---|---|---|
| Blue to purple (default) | `#0969da` / `#8250df` | `#58a6ff` / `#d2a8ff` |
| Green to teal | `#1a7f37` / `#0e8a8a` | `#3fb950` / `#39c5cf` |
| Orange to red | `#bc4c00` / `#cf222e` | `#f0883e` / `#ff7b72` |
| Mono | `#24292f` / `#57606a` | `#e6edf3` / `#8b949e` |

The user may give any other hex colors.

## Logo prompt template

Fill every `<...>`, then hand it to the user for the image generator of their choice:

```text
A minimal, modern logo icon for "<project name>", <one-line purpose>.
Concept: <one concrete visual idea tied to the purpose, for example a folded
map for a navigation tool>. Style: <flat vector | pixel art | soft 3D>,
simple bold silhouette, at most <2 or 3> colors from this palette: <hex list>.
Square 1:1 canvas, 1024x1024, centered with generous padding, transparent
background. Must stay recognizable at 32x32 and read well on both white and
near-black backgrounds. No text, no letters, no watermark, no photo realism,
no gradients that turn muddy at small sizes, no drop shadow outside the icon.
```

Tell the user to save the result as `.github/assets/logo.png` (and `.github/assets/logo-dark.png` for a dark variant), then uncomment the logo block or re-run `repo-docs`. For a single image that works on both backgrounds, drop the `<source>` lines and keep only the `<img>`, with `width` about 128 to 200.

## Custom

Prefer SVG, else PNG with a transparent background. Copy a local file into `.github/assets/` under a lowercase name without spaces; give the `<img>` a meaningful `alt` and a `width`. A URL the user gives is linked as is.

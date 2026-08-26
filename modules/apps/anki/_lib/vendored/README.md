# Vendored Anki add-ons — third-party code

Everything under this directory is **third-party code committed into this
repository**, with two exceptions noted below. The repository's GPL-3.0 licence
(`/LICENSE`, `/COPYRIGHT`) does not apply to any of it: each add-on stays under
the terms its own authors chose, and those terms travel with the code when this
repository is redistributed.

Add-ons are vendored rather than fetched when upstream has no clean source to
build from, or when this repo carries a fork. Add-ons built from upstream at
evaluation time live in `../fetched/` instead.

## What is here

| Directory | Add-on | Licence |
|---|---|---|
| `1100811177` | Syntax Highlighting (fork: css + night mode) | AGPL-3.0 / GPL — see its `LICENSE_AGPL…`, `LICENSE_GPL`, `license.txt` |
| `1247171202` | Study Time Stats | MIT — `LICENSE` |
| `1362209126` | Quizlet to Anki 21 Importer (JDMaybeMD fork) | **not stated upstream** |
| `1442112168` | PDF Exporter | AGPL-3.0 — `LICENSE.txt` |
| `1566095810` | Multiple Choice | AGPL-3.0 — `LICENSE.txt` |
| `1708250053` | Progress Bar (Shigeyuki fork) | AGPL-3.0 — `LICENSE` |
| `175794613` | Anki Leaderboard (Shigeyuki fork) | AGPL-3.0 + MIT; bundled media assets carry **separate attribution terms** — see the several licence files under `media_files/` |
| `1779572689` | Deck duplication | MIT — `LICENSE` |
| `1906641654` | See Previous Ratings | **not stated upstream** |
| `2084557901` | LPCG (Lyrics/Poetry Cloze Generator) | AGPL-3.0 or later — header in `__init__.py`, © Soren Bjornstad |
| `24411424` | Customize Keyboard Shortcuts | **not stated upstream** |
| `2494384865` | Button Colours Good Again | **not stated upstream** |
| `699175524` | Deck name in title 21 | AGPL-3.0 or later — header in `__init__.py` |
| `800604861` | Copy notes (Shigeyuki fork) | GPL — `LICENSE` |
| `805891399` | Extended field editor (tables, search & replace, TinyMCE6) | AGPL-3.0 / GPL; bundles TinyMCE 6 and htmlmin under their own terms |
| `advanced_deck_maker` | **own add-on** — multi-deck creation via `\|\|` splits / `{brace}` expansion | GPL-3.0, same as this repository |
| `efficiency_tracker` | **own add-on** — study efficiency tracker | GPL-3.0, same as this repository |

Some add-ons also bundle their own vendored libraries with further licences of
their own (Pygments under `1100811177/libs/`, tzdata under `175794613/bundle/`,
`tls_requests` under `1362209126/vendor/`). Those licence files are left where
they were.

## Before redistributing

Read the licence files in the add-on directories themselves — the table above is
a summary for orientation, not a legal statement, and the "not stated upstream"
rows mean exactly that: the add-on shipped without a licence file or header, so
its terms are whatever its author intended and never wrote down.

## Adding one

Drop the add-on folder in as `<ankiweb-id>/`, keeping every licence and notice
file it shipped with, then add that id to `vendoredIds` in `../default.nix` and
a row to the table above.

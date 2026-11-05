---
name: mermaid-diagrams
description: |
  Use when the deliverable is Mermaid source: the user names Mermaid, or the
  host renders Mermaid blocks itself (GitHub, Linear, Obsidian) and the
  diagram should stay editable text there. Covers flowcharts, sequence
  diagrams, architecture diagrams, diagram refactors, and readability fixes:
  type selection, reader-first layout, parser-safe syntax, palettes and
  dark-mode-safe styling, renderer compatibility, density control, and render
  validation. NOT for figures delivered as images in documents or posts, or
  draw.io native XML authoring (technical-figure or drawio-diagram from the
  gigio-figures repository, when installed).
---

# Mermaid Diagrams

Produce a Mermaid diagram that a human reads correctly on the first pass and that actually renders on the destination host. Readability outranks completeness: a diagram that needs study has failed even if every fact is in it.

Baseline: Mermaid v11.17 syntax, written down to the version-safe subset when the destination host is older or unknown. Mermaid v12, which GitHub renders, keeps that syntax but changes the default layout, theme, and look (`references/syntax-pitfalls.md`). Keep reusable examples in English with neutral sample domains; for user artifacts, follow the requested or source language and never introduce names, incident details, or unreleased context the user did not provide.

## Reference Files

| File | Read when |
| --- | --- |
| `references/syntax-pitfalls.md` | Before writing any non-trivial diagram, or when a diagram fails to parse — line-break trap, parser breakers, escaping, frontmatter config |
| `references/diagram-catalog.md` | Choosing a type, choosing detail level, or wanting a starting pattern — includes v11 and v12 types and compact-vs-detailed forms |
| `references/color-and-style.md` | When color/emphasis would add meaning — ready palettes, themeVariables, dark-mode survival, hierarchy without color |
| `references/renderer-compat.md` | When the destination host matters or before shipping — host matrix, version gates, validation workflow |

## Non-Negotiable Syntax Rules

The five failures that dominate real-world broken diagrams:

1. **Line breaks are `<br/>`, never `\n`.** Literal `\n` renders as visible `\n` text in sequence messages, notes, and state labels (render-verified), and on older hosts everywhere else.
2. **Quote any label with punctuation**: `A["validate (strict)"]`. Unquoted `()[]{}|;#&` breaks the parser.
3. **Never use lowercase `end`** as a node/label word in flowcharts and sequence diagrams; write `End` or quote it.
4. **Flowchart arrows are `-->`**, not `->`.
5. **Balance every block**: `subgraph`/`end`, `alt`/`end`, `activate +`/`-`.

## Workflow

1. **One message.** State what the reader must be able to verify in one sentence. Split topics that need two sentences into two diagrams.
2. **Type by reader task** (`diagram-catalog.md`): process → `flowchart`, call order → `sequenceDiagram`, boundaries → subgraphs or `architecture-beta`, lifecycle → `stateDiagram-v2`, data model → `erDiagram`.
3. **Direction from the reading path, not habit.** `LR` for comparisons, swimlanes, and handoffs; `TD`/`TB` for short sequential paths and decision trees. Long labels, many branches, or a narrow host argue against `LR`; a scroll-tunnel argues against `TD`. Restructure or split before touching `nodeSpacing`/`rankSpacing`, and treat 12+ nodes, 16+ edges, or many cross-subgraph edges as a signal to simplify.
4. **Draft at the right detail level** (`diagram-catalog.md`): compact form for overviews (chained edges, `&` fan-out, shared terminal nodes, labeled edges instead of trivial diamonds); detailed form for design docs (subgraphs for real boundaries, markdown-string labels, `autonumber`, `alt`/`par` blocks). Labels stay short — sentences belong in prose.
5. **Style only with purpose** (`color-and-style.md`): unstyled is the most portable and often best. When color encodes meaning, use the bundled palettes (fill + stroke + text always set together so dark mode cannot break contrast), pair color with labels or line style, keep to ≤4 colors, and set edge visibility (`linkStyle default stroke:#64748b`) when fills would wash edges out. When edges carry text, set `edgeLabelBackground` and `textColor` together so the label remains readable over lines and on both host themes. Add `accTitle`/`accDescr` when the destination benefits from accessibility metadata.
6. **Validate** (`renderer-compat.md`): for repository markdown, run the bundled density and render scripts (absolute paths, from any cwd):

   ```bash
   SKILL_DIR="<absolute path to this skill>"
   "$SKILL_DIR/scripts/assess_mermaid_density.sh" "<absolute markdown path>"
   "$SKILL_DIR/scripts/validate_mermaid_markdown.sh" "<absolute markdown path>"
   ```

   Render failure blocks; fix and rerun. Density warnings start a visual look, not automatic deletion. Then inspect the rendered output (or host preview) for clipping, literal `\n`, unreadable crossings, and reading order.

   The render script needs Node 22.13+ for mermaid-cli 12 (`renderer-compat.md`) and downloads mermaid-cli and a headless Chromium through `npx -y` on its first run; without Node, network access, or that download, report the syntax review and the visual check as separate claims and state that the render did not run.

   The validator renders with Mermaid 12, as GitHub does; set `MERMAID_CLI_VERSION=11.17.0` for a v11 host such as GitLab or VS Code. Validate against the requested destination, or the documented safe subset when it is unknown. After parsing and visual checks pass, finish; expand to other renderers only when another destination is required or a specific compatibility failure remains.

## Authority

Return what was asked: a code block for "give me a diagram", a file edit for "add/fix the diagram in this doc". Do not restructure surrounding documents, re-theme existing diagrams, or convert diagram types beyond the request; if a different type would serve the reader clearly better, deliver the requested artifact and note the alternative in one sentence.

## Output Contract

Artifact first. Add design notes only for non-obvious choices the user should review (direction choice, what was omitted in a compact form, host caveats). Report validation results only for checks actually run, naming the renderer used; never imply visual inspection happened when only parsing was checked.

## Gotchas

- **Direction defaults hide layout bugs.** Dense `LR` architecture renders impressive and unreadable; sequential `TD` becomes a scroll tunnel. Pick from the reader path, then check the render.
- **A compact diagram that silently dropped a required fact is wrong**, not elegant — say what was compressed out, or split instead.
- **Host version is part of correctness.** Markdown strings, `@{ shape: }`, ELK, and beta diagram types fail or degrade on hosts with older engines (older self-managed GitLab releases, Confluence plugins). Unknown host → version-safe subset.
- **`linkStyle` indexes shift** when edges are added or reordered — re-check indexed styles after any edge edit.
- **Edge labels need their own contrast pair.** Styling nodes and lines does not protect text on an edge; set both `edgeLabelBackground` and `textColor` in `themeVariables`, then inspect the light and dark render.
- **Density thresholds are heuristics.** They trigger a look at the render; required nodes and relationships stay.

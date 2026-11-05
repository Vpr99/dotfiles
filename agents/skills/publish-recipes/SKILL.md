---
name: publish-recipes
description: Imports recipes from a URL into Eric's Obsidian vault and ships the ericskram.com/recipes microsite generated from those notes. Use when Eric pastes a recipe URL ("add this to my recipes", "do <url>"), says "republish recipes", "publish my recipes", "push the recipes to the site", or after adding or editing a recipe note he wants live.
---

# Publish recipes

Notes: `~/Vault/Cooking/` (`type: recipe`). Images: `../Raw/assets/` next to it.
Site repo: `/Users/ericskram/code/personal/ericskram.com`. The generator is `tools/recipes` (Go). It writes static HTML to `recipes/`, which is committed, and Vercel serves it with no build step.

## Import a URL

1. Pull the schema.org `Recipe` JSON-LD. It has ingredients, steps, times, yield, and image in one clean blob. Use defuddle only for intro text.
   - If curl gets a 403/429 (Dishing Up the Dirt, Serious Eats), use agent-browser:
     `agent-browser open <url>`, then `agent-browser eval 'JSON.stringify([...document.querySelectorAll("script[type=\"application/ld+json\"]")].flatMap(s=>[].concat(JSON.parse(s.textContent))).flatMap(x=>x["@graph"]||[x]).find(x=>[].concat(x["@type"]).includes("Recipe")))'`, then `agent-browser close`. This handles `@graph` wrappers and array `@type`s.
   - If the title is "Just a moment..." (Cloudflare, e.g. Serious Eats), close and reopen with `agent-browser --headed open <url>`. Headless never clears it.
   - An article (no Recipe JSON-LD) usually links to the actual recipe under "Get The Recipes". Import that, and fold the article's technique into steps or an extra section.
2. Check the data against the steps. Sites ship typos, like a `cookTime` of `PT2M` on a 2-hour simmer. Trust the steps.
3. Download the hero image to `Raw/assets/<slug>.jpg` and run `file` on it to confirm it's a real image.
4. Write `Cooking/<Title in sentence case>.md`:

```markdown
---
type: recipe
title: "Split pea and ham soup"
category: main          # main | side | sauce | dessert | bread | drink | technique
cuisine: american
servings: 4             # or free text: "3 mini loaves or 1 large loaf", "6–8 servings"
time_total: "2h15m"
time_active: "20m"
difficulty: easy
status: untested
source: "<url>"
tags: [recipe, main, soup]
created: <today>
updated: <today>
last_made: ""
---

# Split pea and ham soup

One or two sentences. This becomes the meta description only; it is NOT rendered on the page, so links here do nothing.

![[Raw/assets/split-pea-ham-soup.jpg]]

## Ingredients

### Subgroup (optional)

- 1 lb dried split peas

## Instructions

1. **Simmer (2h):** Step text.

## Origin

[Site — Original Title](<url>)
```

- Break run-on source steps into one action per step, each with a `**Label (time):**` lead-in.
- Turn substitutions and asides into `> [!tip]` callouts under the step.
- Strip shop links from ingredients.
- A sub-recipe (icing, sauce) gets its own note, linked as `[[Royal icing]]` from the parent's ingredients and steps.
- When Eric changes the source (bake time, liquid), use his number and add a `> [!tip]` with the original and "not yet tested".
- Adapting a method (e.g. Instant Pot) makes it the primary `## Instructions`; the stovetop original stays a link in `## Origin`, not a second copy.

## Publish

1. `cd /Users/ericskram/code/personal/ericskram.com && git checkout main && git pull`
2. Branch: `git checkout -b eric/recipes-<slug-of-what-changed>`. Date-only names collide on the second run of the day.
3. Generate: `go -C tools/recipes test ./... && go -C tools/recipes run . -out ../../recipes`
   - It wipes and rewrites `recipes/`. Read every log line: missing embeds get dropped from the page, and a frontmatter type error aborts the run.
4. Review: `git status --short` should show only the recipes you meant to change. For a new one, strip tags from `recipes/<slug>/index.html` and check the vitals, ingredients, steps, and callouts.
5. Commit ("Republished recipes (added X)"), push, `gh pr create --fill --base main`. Ask Eric before pushing. If he says merge (he usually does), run `gh pr merge --squash --delete-branch`. Merging deploys on Vercel.

## What gets published

- Every `type: recipe` note that has both ingredients and at least one real (non-placeholder) instruction step. Stubs like Pretzels and Chocolate tempering are skipped automatically.
- `publish: false` in a note's frontmatter excludes it.
- Never published: `## Log`, `## Batch log`, `## Source scans`, `status`, `last_made`. Affiliate links (amzn.to, `tag=`) are stripped to plain text.
- If a note is skipped unexpectedly, check its `## Ingredients` / `## Instructions` headings. The parser expects those exact names, with `###` subgroups and `1.` numbered steps.

## Syntax the generator understands

- `servings`: a bare number renders as "N servings"; anything else renders as written. Either way it fills the Yield box and the JSON-LD `recipeYield`.
- Steps can't nest lists: bullets under a numbered step are dropped. Put them in their own `## Section` (any unknown `##` renders as a prose block after the directions).
- Markdown links and `[[wikilinks]]` render in ingredient text, step text, and extra sections.
- `**Label (time):** text` at the start of a step fills the step-name and time columns of the directions table.
- A `> [!tip] Title` callout directly after a step becomes that step's red note.
- A table in `## Ingredients` (Weight | Ingredient | Baker's %) becomes rows with a baker's % column. Bullets after the table become italic footnotes.
- `## Vitals` bullets (`- Label: value`) become extra boxes in the vitals row, replacing a built-in box with the same label.
- The first `![[image]]` in the intro becomes the hero image (copied next to the page). Other intro text only feeds the meta description.
- `[[Other recipe]]` in ingredients or steps links to its page when that recipe is published; otherwise it renders as plain text.

# Multi-model convention validation

Goal: empirically test whether Dialect's convention file produces convergent output across **any AI model**. Dialect's README claims it's editor-agnostic ("works with Cursor, Copilot, Windsurf, Claude Code, and anything else"). This exercise proves or refutes the claim.

Run as many models as you have access to — Claude, ChatGPT, Gemini, Mistral, Qwen, DeepSeek, Grok, anything else. Each one creates its own folder under `_validation/runs/` and writes its output there. If they all produce equivalent ARB and translation files from the same frozen inputs, the convention is robust. If they diverge wildly, the convention has gaps to close.

This harness was reset on **2026-05-24** against the complete v1.0 package. An earlier validation round (April–May 2026) caught one convention defect — Codex omitting Arabic CLDR plural categories — which was fixed in the current `dialect.yaml` "Plurals" section. This round retests the convention against a larger surface area: five screens, plurals over different counts (=0/=1/other and one/other), glossary terms in verb / noun / possessive constructions, and the usual demo-data discipline traps.

---

## Test-integrity rules — read first

The whole point is a **fair comparison**. That requires strict isolation. Violations invalidate the result.

1. **Each model writes only to its own folder under `examples/_validation/runs/<model>/`.** No model writes to `examples/after/` or to any other model's folder.
2. **Each model reads only from a small frozen allowlist** (see "Inputs" below). It does not read `CLAUDE.md`, `docs/`, `planning/`, `README.md`, `examples/after/`, or any other model's run.
3. **Models do not see each other's output.** Run them one at a time. Do not paste another model's results into a new model's chat as "context" or "example."
4. **Models do not see the validation report or this file.** They get only the prompt block below.
5. **No follow-up corrections.** Whatever the model produces in the first pass is the artifact. If the model gets it wrong, that's a convention gap, not a model failure.
6. **The model creates its own output folder** if it doesn't exist (`_validation/runs/<model>/dialect/source/` and `_validation/runs/<model>/dialect/translations/`). Don't pre-create them.

---

## Directory layout

```
examples/
├── before/                         # Bare Flutter app — READ-ONLY input shared by all runs
│   ├── lib/                        # the Dart source the model extracts strings from
│   └── pubspec.yaml                # OUT OF SCOPE for the models
├── after/                          # Clone of before/ — OUT OF SCOPE for the models
└── _validation/
    ├── INSTRUCTIONS.md             # this file (humans only — models never see it)
    ├── inputs/                     # FROZEN, READ-ONLY for all models
    │   └── dialect/
    │       ├── dialect.yaml        # the convention under test
    │       ├── glossary.yaml
    │       ├── source/en.arb       # 4 seed keys — the model expands a copy of this
    │       └── translations/       # empty
    └── runs/                       # WRITE targets — each model creates one
        └── <model-name>/           # created by each model (gpt, gemini, claude-sonnet, …)
```

## Inputs the model may read (the entire allowlist)

```
examples/before/lib/main.dart
examples/before/lib/screens/checkout_screen.dart
examples/before/lib/screens/settings_screen.dart
examples/before/lib/widgets/loading_indicator.dart
examples/_validation/inputs/dialect/dialect.yaml
examples/_validation/inputs/dialect/glossary.yaml
examples/_validation/inputs/dialect/source/en.arb
```

That's it. Seven files. The model reads no others.

## Outputs the model writes (its sandbox)

```
examples/_validation/runs/<model>/MODEL.md
examples/_validation/runs/<model>/dialect/source/en.arb            # expanded version of the seed
examples/_validation/runs/<model>/dialect/translations/<locale>.arb   # one per target locale
```

The model creates `examples/_validation/runs/<model>/` and any subdirectories itself.

---

## The prompt (universal — works for any model)

The prompt is shaped like a **real Flutter developer's chat message** because that's the realistic test. The convention file itself does the teaching — that's the whole point of Dialect. Paste verbatim; don't expand it into a recipe.

> **For models with filesystem access** (Claude Code, Codex CLI, Gemini Code Assist, Cursor agent mode, etc.): paste the prompt as-is.
>
> **For chat-only models** (web ChatGPT, web Gemini, web Claude, etc.): also paste the contents of all input files first, labeled with their paths (see "Chat-only fallback" below). Then paste the prompt. The model returns labeled output blocks you copy into the right files.

```
I just built out my Flutter app. Please add localization for it — read
@examples/_validation/inputs/dialect/dialect.yaml for the convention
(target locales, glossary, naming rules, what to extract and what not to).
The screens are under examples/before/lib/.

Two ground rules for this run only (it's a comparison harness for evaluating
how consistently different AI models follow the convention):

  1. Write your output under examples/_validation/runs/<your-folder>/dialect/
     instead of touching examples/before/ or examples/after/. Pick
     <your-folder> from your model family — e.g. `gpt-5`,
     `claude-sonnet-4-6`, `gemini-2.5-pro`, `mistral-large`, `qwen3`,
     `deepseek-v3`. Also drop a short
     examples/_validation/runs/<your-folder>/MODEL.md with: model name,
     interface used, today's date, and any active custom system prompt
     (or "none").

  2. Don't read CLAUDE.md, docs/, planning/, README.md, examples/after/, or
     other models' runs under examples/_validation/runs/. The convention
     should be self-sufficient — if you find yourself wanting another file,
     that's a convention gap; note it and proceed with reasonable defaults.

One pass — no follow-up corrections. Briefly in your final reply: what was
clear, what was ambiguous, and how confident you are that another AI
reading the same files cold would land in the same place.
```

That's the whole prompt. No 7-step recipe, no allowlist enumeration — the convention at `@dialect.yaml` is what teaches the model what to do. If it can't, that's the signal we're looking for.

---

## After at least three runs are done

Say *"compare the runs in `_validation/runs/`"* to Claude. It will read each `_validation/runs/<model>/` directory and write `_validation/COMPARISON.md` analyzing convergence on these axes:

1. **Key coverage** — same set of strings extracted across the five screens?
2. **Key naming** — same `namespace.camelCaseKey` choices?
3. **Namespace inventions** — did each model add `home`, `trips`, `hosting`, or anything else?
4. **Demo-data discipline** — did each correctly skip personal names (`Linh`, `Minh`, `An`), language self-names (`English`), sample listing titles (`Lakeside cabin in Sapa`), currency amounts, dates?
5. **`@key` description quality** — specific and contextual, or generic?
6. **Glossary application** — prescribed translations for Book / Host / Trip, including inflection (verb vs noun vs possessive)?
7. **Plural categories per locale** — Arabic 6-form, Japanese/Vietnamese 1-form, German/Spanish 2-form?
8. **Placeholder preservation** — same names byte-identically across translations?
9. **Tone / formality** — matches the per-locale style block in glossary?
10. **Translation quality** — judgment call; native-speaker review may be needed for the final word.

A convention that scores high on 1–4 across every model has done its job. 5–10 reflect model capability more than convention quality.

---

## Chat-only fallback (assemble file dump)

If a model can't read files, paste the prompt block above plus a file dump assembled with:

```bash
cd /Users/chaucao/Documents/github/dialect
{
  for f in \
    examples/_validation/inputs/dialect/dialect.yaml \
    examples/_validation/inputs/dialect/glossary.yaml \
    examples/_validation/inputs/dialect/source/en.arb \
    examples/before/lib/main.dart \
    examples/before/lib/screens/checkout_screen.dart \
    examples/before/lib/screens/settings_screen.dart \
    examples/before/lib/widgets/loading_indicator.dart
  do
    echo "=== File: $f ==="
    cat "$f"
    echo
  done
} | pbcopy
```

That puts the file dump on your clipboard. Paste it into the chat **before** the prompt block. Ask the model to return its output as labeled code blocks (one per file), which you then save manually under `examples/_validation/runs/<model>/dialect/`.

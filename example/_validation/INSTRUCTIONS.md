# Multi-model convention validation

Goal: empirically test whether Dialect's convention file produces convergent output across **any AI model**. Dialect's README claims it's editor-agnostic ("works with Cursor, Copilot, Windsurf, Claude Code, and anything else"). This exercise proves or refutes the claim.

Run as many models as you have access to — Claude, ChatGPT, Gemini, Mistral, Qwen, DeepSeek, Grok, anything else. Each one creates its own folder under `_validation/runs/` and writes its output there. If they all produce equivalent ARB and translation files from the same frozen inputs, the convention is robust. If they diverge wildly, the convention has gaps to close before tagging v1.0.

---

## Test-integrity rules — read first

The whole point is a **fair comparison**. That requires strict isolation. Violations invalidate the result.

1. **Each model writes only to its own folder under `_validation/runs/<model>/`.** No model writes to `example/dialect/` (the live workspace) or to any other model's folder.
2. **Each model reads only from a small frozen allowlist** (see "Inputs" below). It does not read `CLAUDE.md`, `docs/`, `planning/`, `README.md`, the live `example/dialect/`, the live `example/pubspec.yaml`, or any other model's run.
3. **Models do not see each other's output.** Run them one at a time. Do not paste another model's results into a new model's chat as "context" or "example."
4. **Models do not see the validation report or this file.** They get only the prompt block below.
5. **No follow-up corrections.** Whatever the model produces in the first pass is the artifact. If the model gets it wrong, that's a convention gap, not a model failure.
6. **The model creates its own output folder** if it doesn't exist (`_validation/runs/<model>/dialect/source/` and `_validation/runs/<model>/dialect/translations/`). Don't pre-create them.

---

## Directory layout

```
example/
├── lib/                            # Flutter source — READ-ONLY input shared by all runs
├── pubspec.yaml                    # OUT OF SCOPE for the models
├── dialect/                        # LIVE workspace — OUT OF SCOPE for the models
└── _validation/
    ├── INSTRUCTIONS.md             # this file (humans only — models never see it)
    ├── inputs/                     # FROZEN, READ-ONLY for all models
    │   └── dialect/
    │       ├── dialect.yaml        # patched convention
    │       ├── glossary.yaml
    │       ├── source/en.arb       # 4 seed keys — the model expands a copy of this
    │       └── translations/       # empty
    └── runs/                       # WRITE targets — each model creates one
        ├── claude-pre-patch/       # historical (pre-patch convention) — see NOTE.md
        ├── claude-post-patch/      # filled
        └── <model-name>/           # created by each model (gpt, gemini, mistral, …)
```

## Inputs the model may read (the entire allowlist)

```
example/lib/main.dart
example/lib/screens/checkout_screen.dart
example/lib/screens/settings_screen.dart
example/lib/widgets/loading_indicator.dart
example/_validation/inputs/dialect/dialect.yaml
example/_validation/inputs/dialect/glossary.yaml
example/_validation/inputs/dialect/source/en.arb
```

That's it. Seven files. The model reads no others.

## Outputs the model writes (its sandbox)

```
example/_validation/runs/<model>/dialect/source/en.arb            # expanded version of the seed
example/_validation/runs/<model>/dialect/translations/<locale>.arb   # one per target locale
```

The model creates `_validation/runs/<model>/` and any subdirectories itself.

---

## The prompt (universal — works for any model)

One prompt, any model. The model picks its own folder name based on what it is. Paste it verbatim — no edits.

> **For models with filesystem access** (Claude Code, Codex CLI, Gemini Code Assist, Cursor agent mode, etc.): paste the prompt as-is.
>
> **For chat-only models** (web ChatGPT, web Gemini, web Claude, etc.): also paste the contents of all 7 input files first, labeled with their paths (see "Chat-only fallback" below). Then paste the prompt. The model returns labeled output blocks you copy into the right files.

```
You are an AI coding assistant helping a Flutter developer add internationalization to their app. This is a normal day-to-day task. You have no special knowledge of any "Dialect" tool — treat this as a colleague pointing you at a folder.

Working directory: /Users/chaucao/Documents/github/dialect/example/

# Your output folder

Before anything else: pick a short, lowercase, hyphen-separated folder name that identifies you. Use your model family. If multiple versions of the same family are being tested, include the version. Examples: `gpt`, `gpt-5`, `gemini`, `gemini-2.5-pro`, `claude`, `mistral-large`, `qwen3`, `deepseek-v3`, `grok-4`. Pick one and use it consistently for every file you write in this task. Refer to this folder as <YOUR_FOLDER> below.

The first file you create is:

  _validation/runs/<YOUR_FOLDER>/MODEL.md

It contains exactly four short lines:
  - Model family and version (e.g. "GPT-5", "Gemini 2.5 Pro", "Claude Sonnet 4.6")
  - Interface used (e.g. "ChatGPT web", "Gemini CLI", "Claude Code", "via OpenRouter")
  - Date you ran it (today's date, ISO format)
  - One sentence on any custom system prompt or persona that was active in your session, or "none"

# Files you MAY read (the full allowlist — read no others)

- lib/main.dart
- lib/screens/checkout_screen.dart
- lib/screens/settings_screen.dart
- lib/widgets/loading_indicator.dart
- _validation/inputs/dialect/dialect.yaml
- _validation/inputs/dialect/glossary.yaml
- _validation/inputs/dialect/source/en.arb

Do NOT read anything outside this list. Specifically, do NOT read CLAUDE.md, docs/, planning/, README.md, the live dialect/ folder, pubspec.yaml, or any sibling under _validation/runs/ (other models' work — treat as off-limits). If you find yourself wanting another file, that signals the convention is incomplete — note it and proceed.

# Files you MAY write (your sandbox — create the folders if they don't exist)

- _validation/runs/<YOUR_FOLDER>/MODEL.md
- _validation/runs/<YOUR_FOLDER>/dialect/source/en.arb            (expanded copy of the seed)
- _validation/runs/<YOUR_FOLDER>/dialect/translations/<locale>.arb   (one file per target locale)

Do NOT write anywhere else. Do NOT touch example/dialect/. Do NOT touch _validation/inputs/. Do NOT touch any sibling _validation/runs/ folder.

# What to do

1. Pick <YOUR_FOLDER> and write _validation/runs/<YOUR_FOLDER>/MODEL.md.
2. Read _validation/inputs/dialect/dialect.yaml in full. Follow its instructions.
3. Read _validation/inputs/dialect/glossary.yaml.
4. Read _validation/inputs/dialect/source/en.arb — these 4 keys are already canonical, do not modify them; your expanded en.arb must include them unchanged.
5. Read the Flutter source under lib/.
6. Extract every user-facing string from lib/ that the convention says should be extracted. Add them as new keys to your en.arb output. The 4 seed keys appear unchanged; new keys are added.
7. For every key in the resulting en.arb, produce a translation for every target locale named in dialect.yaml. Write one translation file per locale.

# Hard constraints

- Do not ask clarifying questions. Make reasonable calls on ambiguities and note them in your final report.
- One pass. No iteration based on outside feedback.

# Final report (in your chat reply, not as a written file)

- What was clear in the convention.
- What was ambiguous and what you chose.
- Anything that would trip up a less careful agent.
- How confident are you that another AI agent reading the same files cold would produce identical or near-identical output? Be candid.
```

### Already-run models

Claude has two snapshots:
- `_validation/runs/claude-pre-patch/` — historical, against pre-patch convention.
- `_validation/runs/claude-post-patch/` — against the current patched convention.

You don't need to run Claude again unless you want to test a specific Claude version (e.g. Sonnet vs Opus) — in which case it follows the universal prompt above and picks its own folder name (e.g. `claude-sonnet`, `claude-opus`).

---

## After all three runs are done

Run the comparison by saying *"compare the three runs"* to Claude. It will read all three `_validation/runs/<model>/` directories and write `_validation/COMPARISON.md` analyzing convergence on these 10 axes:

1. **Key coverage** — same set of strings extracted?
2. **Key naming** — same `namespace.camelCaseKey` choices?
3. **Namespace inventions** — did each model add `home` (or anything else)?
4. **Demo-data discipline** — did each correctly skip personal names, emails, language self-names, currency amounts?
5. **`@key` description quality** — specific and contextual, or generic?
6. **Glossary application** — prescribed translations for Book / Host / Trip, including inflection?
7. **Plural categories per locale** — Arabic 6-form, Japanese/Vietnamese 1-form, German/Spanish 2-form?
8. **Placeholder preservation** — same names byte-identically across translations?
9. **Tone / formality** — matches the per-locale style block in glossary?
10. **Translation quality** — judgment call; native-speaker review may be needed for the final word.

A convention that scores high on 1–4 across every model has done its job. 5–10 reflect model capability more than convention quality.

---

## Chat-only fallback (assemble file dump)

If a model can't read files, paste the prompt block above plus a file dump assembled with:

```bash
cd /Users/chaucao/Documents/github/dialect/example
{
  for f in \
    _validation/inputs/dialect/dialect.yaml \
    _validation/inputs/dialect/glossary.yaml \
    _validation/inputs/dialect/source/en.arb \
    lib/main.dart \
    lib/screens/checkout_screen.dart \
    lib/screens/settings_screen.dart \
    lib/widgets/loading_indicator.dart
  do
    echo "=== File: example/$f ==="
    cat "$f"
    echo
  done
} | pbcopy
```

That puts the file dump on your clipboard. Paste it into the chat **before** the prompt block. Ask the model to return its output as labeled code blocks (one per file), which you then save manually under `_validation/runs/<model>/dialect/`.

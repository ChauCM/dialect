#!/usr/bin/env python3
"""Render README.md into a standalone index.html for dialect.tools.

Wraps the rendered Markdown in the same CSS shell the hand-authored
landing used so the look survives the swap. Run from the repo root:

    python3 tool/render_landing.py > out/index.html

Dependencies: stdlib only. Uses the `markdown` package if available
(fenced code + tables + smarty), falls back to a minimal renderer
otherwise. CI is expected to install `markdown` first.
"""

import html
import re
import sys
from pathlib import Path


CSS = """
:root {
  --bg: #fafafa;
  --fg: #18181b;
  --fg-muted: #52525b;
  --fg-subtle: #71717a;
  --border: #e4e4e7;
  --accent: #4f46e5;
  --accent-soft: #eef2ff;
  --code-bg: #18181b;
  --code-fg: #e4e4e7;
  --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  -webkit-font-smoothing: antialiased;
}
.container {
  max-width: 760px;
  margin: 0 auto;
  padding: 64px 24px 96px;
}
h1 { font-size: 40px; line-height: 1.15; font-weight: 700; margin: 8px 0 16px; letter-spacing: -0.02em; }
h2 { font-size: 22px; font-weight: 600; margin: 48px 0 12px; letter-spacing: -0.01em; }
h3 { font-size: 17px; font-weight: 600; margin: 32px 0 8px; }
h4 { font-size: 15px; font-weight: 600; margin: 24px 0 6px; color: var(--fg-muted); }
p, li { color: var(--fg); }
a { color: var(--accent); text-decoration: none; }
a:hover { text-decoration: underline; }
hr { border: 0; border-top: 1px solid var(--border); margin: 48px 0; }
blockquote {
  border-left: 3px solid var(--accent);
  background: var(--accent-soft);
  margin: 16px 0; padding: 12px 16px;
  color: var(--fg-muted);
}
ul, ol { padding-left: 24px; }
li { margin: 4px 0; }
pre {
  background: var(--code-bg);
  color: var(--code-fg);
  font-family: var(--mono);
  font-size: 13.5px;
  padding: 16px 20px;
  border-radius: 8px;
  overflow-x: auto;
  line-height: 1.55;
  margin: 12px 0 20px;
}
pre code { background: transparent; padding: 0; color: inherit; font-size: inherit; }
code {
  font-family: var(--mono);
  font-size: 0.9em;
  background: var(--accent-soft);
  color: var(--accent);
  padding: 1px 6px;
  border-radius: 4px;
}
table { border-collapse: collapse; margin: 12px 0 20px; font-size: 14px; }
th, td { border: 1px solid var(--border); padding: 6px 12px; text-align: left; }
th { background: var(--accent-soft); }
details {
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 8px 14px;
  margin: 8px 0;
  background: #fff;
}
details summary { cursor: pointer; font-weight: 600; }
details[open] summary { margin-bottom: 8px; }
img { max-width: 100%; border-radius: 6px; }
footer {
  margin-top: 64px;
  padding-top: 24px;
  border-top: 1px solid var(--border);
  color: var(--fg-subtle);
  font-size: 13px;
}
footer a { color: var(--fg-muted); }
""".strip()


HEAD = """<!doctype html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>{title}</title>
<meta name="description" content="AI-native localization toolkit for Flutter-led teams." />
<meta property="og:title" content="{title}" />
<meta property="og:description" content="One canonical source, every platform, driven by your AI editor." />
<meta property="og:url" content="https://dialect.tools" />
<link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 32 32'%3E%3Crect width='32' height='32' rx='6' fill='%234f46e5'/%3E%3Ctext x='16' y='22' text-anchor='middle' font-family='ui-monospace,Menlo,monospace' font-size='18' fill='white' font-weight='600'%3ED%3C/text%3E%3C/svg%3E" />
<style>{css}</style>
</head>
<body>
<div class="container">
"""


FOOTER = """
<footer>
  <a href="https://github.com/ChauCM/dialect">github.com/ChauCM/dialect</a> ·
  <a href="https://pub.dev/packages/dialect">pub.dev/packages/dialect</a> ·
  <a href="https://dialect.tools/install.sh">install.sh</a>
</footer>
</div>
</body>
</html>
"""


def render(readme: str) -> str:
    try:
        import markdown  # type: ignore
        body = markdown.markdown(
            readme,
            extensions=[
                "fenced_code",
                "tables",
                "sane_lists",
                "smarty",
                "toc",
            ],
            output_format="html5",
        )
    except ImportError:
        body = _minimal_markdown(readme)
    title = _extract_title(readme) or "Dialect — AI-native localization"
    return (
        HEAD.format(title=html.escape(title), css=CSS)
        + body
        + FOOTER
    )


def _extract_title(md: str) -> str:
    for line in md.splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return ""


def _minimal_markdown(md: str) -> str:
    """Tiny fallback renderer if the `markdown` package is unavailable.

    Handles fenced code blocks, headings, and paragraphs at minimum so
    the page still ships if pip-install fails in CI.
    """
    out: list[str] = []
    in_code = False
    for line in md.splitlines():
        if line.startswith("```"):
            if in_code:
                out.append("</code></pre>")
                in_code = False
            else:
                out.append("<pre><code>")
                in_code = True
            continue
        if in_code:
            out.append(html.escape(line))
            continue
        m = re.match(r"^(#{1,4})\s+(.*)$", line)
        if m:
            level = len(m.group(1))
            out.append(f"<h{level}>{html.escape(m.group(2))}</h{level}>")
        elif line.strip() == "":
            out.append("")
        else:
            out.append(f"<p>{html.escape(line)}</p>")
    return "\n".join(out)


def main() -> int:
    readme_path = Path(__file__).resolve().parent.parent / "README.md"
    readme = readme_path.read_text(encoding="utf-8")
    sys.stdout.write(render(readme))
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Refresh <script id=\"embedded-queries\"> and embedded-tables in webDemonstration.html from data/*.json."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
HTML = ROOT / "webDemonstration.html"
DATA = ROOT / "data"


def _json_for_script_tag(obj: object) -> str:
    """Single-line JSON safe inside <script>: no raw control chars; no premature </script>."""
    s = json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
    json.loads(s)  # sanity check
    # HTML: </script> in text would close the element; \/ is valid in JSON
    s = s.replace("</", "<\\/")
    return s


def main() -> None:
    html = HTML.read_text(encoding="utf-8")
    queries = json.loads((DATA / "queries.json").read_text(encoding="utf-8"))
    tables = json.loads((DATA / "tables_preview.json").read_text(encoding="utf-8"))

    q_js = _json_for_script_tag(queries)
    t_js = _json_for_script_tag(tables)

    # re.sub(repl_string) treats "\\n" in repl as real newlines — must not pass JSON as repl template.
    html = re.sub(
        r'<script id="embedded-queries" type="application/json">.*?</script>',
        lambda _m: f'<script id="embedded-queries" type="application/json">{q_js}</script>',
        html,
        count=1,
        flags=re.DOTALL,
    )
    html = re.sub(
        r'<script id="embedded-tables" type="application/json">.*?</script>',
        lambda _m: f'<script id="embedded-tables" type="application/json">{t_js}</script>',
        html,
        count=1,
        flags=re.DOTALL,
    )
    HTML.write_text(html, encoding="utf-8")
    print("Updated embedded JSON in", HTML)


if __name__ == "__main__":
    main()

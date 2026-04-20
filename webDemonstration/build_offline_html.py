"""
Build a single-file offline HTML that works via double-click (file://):
- Embeds queries.json, tables_preview.json, schema_and_rules.json, and ER diagram text
- Uses a local mermaid bundle (vendor/mermaid.min.js)
Output: webDemonstration.html
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
OUT = ROOT / "webDemonstration.html"


def main() -> None:
    queries = json.loads((DATA / "queries.json").read_text(encoding="utf-8"))
    tables = json.loads((DATA / "tables_preview.json").read_text(encoding="utf-8"))
    schema = json.loads((DATA / "schema_and_rules.json").read_text(encoding="utf-8"))
    er = (ROOT.parent / "hospital_er_diagram.mmd").read_text(encoding="utf-8")

    # Build from the template index.html (offline-friendly: local mermaid + non-module app.js).
    html = (ROOT / "index.html").read_text(encoding="utf-8")

    payload = "\n".join(
        [
            '<script id="embedded-queries" type="application/json">' + json.dumps(queries, ensure_ascii=False) + "</script>",
            '<script id="embedded-tables" type="application/json">' + json.dumps(tables, ensure_ascii=False) + "</script>",
            '<script id="embedded-schema" type="application/json">' + json.dumps(schema, ensure_ascii=False) + "</script>",
            '<script id="embedded-er" type="text/plain">' + er.replace("</script>", "<\\/script>") + "</script>",
        ]
    )

    marker = '<script src="./app.js"></script>'
    if marker not in html:
        raise RuntimeError("app.js marker not found in index.html")

    html = html.replace(marker, payload + "\n" + marker)

    OUT.write_text(html, encoding="utf-8")


if __name__ == "__main__":
    main()


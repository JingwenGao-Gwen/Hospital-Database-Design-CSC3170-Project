"""
Generate static practice-site data (no backend):
- Parses import_data.sql INSERT blocks to obtain first N rows per table
- Extracts CREATE TABLE statements and trigger messages from seed.sql
- Writes JSON fixtures under sql_practice_site/data/
"""

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SQL_FILE = ROOT.parent / "import_data.sql"
SEED_FILE = ROOT.parent / "seed.sql"
OUT_DIR = ROOT / "data"

MAX_ROWS: int | None = None  # None = all rows


def _split_tuples(values_sql: str) -> list[str]:
    """Split "(..),(..),(...)" into list of "(..)" tuple strings (top-level only)."""
    out: list[str] = []
    i = 0
    n = len(values_sql)
    while i < n:
        # skip whitespace/commas/newlines
        while i < n and values_sql[i] in " \t\r\n,":
            i += 1
        if i >= n:
            break
        if values_sql[i] != "(":
            # unexpected token, stop
            break
        start = i
        depth = 0
        in_str = False
        while i < n:
            ch = values_sql[i]
            if in_str:
                if ch == "'":
                    # handle escaped single quote ''
                    if i + 1 < n and values_sql[i + 1] == "'":
                        i += 2
                        continue
                    in_str = False
                    i += 1
                    continue
                i += 1
                continue
            else:
                if ch == "'":
                    in_str = True
                    i += 1
                    continue
                if ch == "(":
                    depth += 1
                elif ch == ")":
                    depth -= 1
                    if depth == 0:
                        i += 1
                        out.append(values_sql[start:i])
                        break
                i += 1
        # move past any trailing comma
        while i < n and values_sql[i] in " \t\r\n,":
            i += 1
    return out


def _parse_tuple(t: str) -> list[object]:
    assert t.startswith("(") and t.endswith(")")
    s = t[1:-1]
    vals: list[object] = []
    buf = []
    in_str = False
    i = 0
    n = len(s)
    while i <= n:
        ch = s[i] if i < n else None
        if in_str:
            if ch == "'":
                if i + 1 < n and s[i + 1] == "'":
                    buf.append("'")
                    i += 2
                    continue
                in_str = False
                i += 1
                continue
            if ch is None:
                break
            buf.append(ch)
            i += 1
            continue
        else:
            if ch == "'":
                in_str = True
                i += 1
                continue
            if ch is None or ch == ",":
                token = "".join(buf).strip()
                buf = []
                if token.upper() == "NULL" or token == "":
                    vals.append(None)
                else:
                    # number?
                    if re.fullmatch(r"-?\d+", token):
                        vals.append(int(token))
                    elif re.fullmatch(r"-?\d+\.\d+", token):
                        vals.append(float(token))
                    else:
                        vals.append(token)
                i += 1
                continue
            buf.append(ch)
            i += 1
    return vals


def parse_import_data(sql_text: str) -> dict[str, dict[str, object]]:
    tables: dict[str, dict[str, object]] = {}
    # Non-greedy capture of INSERT blocks, across newlines.
    pat = re.compile(
        r"INSERT\s+INTO\s+([A-Za-z_]+)\s*\(([^)]+)\)\s*VALUES\s*(.+?);",
        re.DOTALL | re.IGNORECASE,
    )
    for m in pat.finditer(sql_text):
        table = m.group(1)
        cols = [c.strip() for c in m.group(2).split(",")]
        values_sql = m.group(3).strip()
        tuples = _split_tuples(values_sql)
        rows: list[list[object]] = []
        use = tuples if MAX_ROWS is None else tuples[:MAX_ROWS]
        for t in use:
            rows.append(_parse_tuple(t))
        tables[table.lower()] = {"columns": cols, "rows": rows}
    return tables


def extract_schema_and_rules(seed_text: str) -> dict[str, object]:
    # CREATE TABLE blocks
    create_pat = re.compile(r"(CREATE\s+TABLE\s+[A-Za-z_]+\s*\(.*?\);\s*)", re.DOTALL | re.IGNORECASE)
    creates = create_pat.findall(seed_text)
    # Triggers: keep the SIGNAL messages so we can show "expected error" text
    msg_pat = re.compile(r"SET\s+MESSAGE_TEXT\s*=\s*'([^']*)'", re.IGNORECASE)
    messages = sorted(set(msg_pat.findall(seed_text)))
    return {"create_tables_sql": creates, "trigger_messages": messages}


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    sql_text = SQL_FILE.read_text(encoding="utf-8")
    seed_text = SEED_FILE.read_text(encoding="utf-8")

    tables = parse_import_data(sql_text)
    meta = extract_schema_and_rules(seed_text)

    (OUT_DIR / "tables_preview.json").write_text(
        json.dumps({"max_rows": MAX_ROWS, "tables": tables}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (OUT_DIR / "schema_and_rules.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()


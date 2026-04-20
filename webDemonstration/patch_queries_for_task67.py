"""Merge Task 6 / Task 7 into data/queries.json and refresh embedded HTML."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
PROJECT = ROOT.parent


def strip_use(sql: str) -> str:
    return re.sub(r"^\s*USE\s+[^;]+;\s*", "", sql, flags=re.I | re.M).strip()


def parse_task6(text: str) -> list[tuple[str, str]]:
    text = strip_use(text)
    chunks = re.split(r"(?=--\s*Query\s+\d+:)", text)
    out: list[tuple[str, str]] = []
    for ch in chunks:
        ch = ch.strip()
        if not ch or not re.search(r"\bSELECT\b", ch, re.I):
            continue
        m = re.match(r"--\s*Query\s+\d+:\s*(.+?)(?:\n|$)", ch)
        title = m.group(1).strip() if m else "Task 6 query"
        out.append((title, ch))
    return out


def parse_task7(text: str) -> list[tuple[str, str]]:
    text = strip_use(text)
    # Remove only the two-line Task 7 assignment header. Do NOT use `(?:--.*)*` — that would
    # also strip `-- 1. Data mining ...` before the first query.
    text = re.sub(
        r"^--\s*Task\s*7[^\n]*\n--\s*[^\n]*\n\s*",
        "",
        text,
        count=1,
        flags=re.I | re.M,
    )
    parts = re.split(r"(?=--\s*[1-4]\.\s)", text)
    out: list[tuple[str, str]] = []
    for ch in parts:
        ch = ch.strip()
        if not ch or not re.search(r"\b(WITH|SELECT)\b", ch, re.I):
            continue
        m = re.match(r"--\s*[1-4]\.\s*(.+?)(?:\n|$)", ch)
        title = m.group(1).strip() if m else "Task 7 query"
        out.append((title, ch))
    return out


def main() -> None:
    t6_path = PROJECT / "task_6_queries(1).sql"
    t7_path = PROJECT / "task_7_queries(1).sql"
    if not t6_path.exists():
        t6_path = PROJECT / "task_6_queries.sql"
    if not t7_path.exists():
        t7_path = PROJECT / "task_7_queries.sql"

    t6_text = t6_path.read_text(encoding="utf-8")
    t7_text = t7_path.read_text(encoding="utf-8")

    q6 = parse_task6(t6_text)
    q7 = parse_task7(t7_text)

    queries = json.loads((DATA / "queries.json").read_text(encoding="utf-8"))
    # Idempotent: remove previously merged Task 6/7 so re-runs do not duplicate groups.
    queries["groups"] = [
        g for g in queries["groups"] if g.get("id") not in ("task_6", "task_7", "sample_queries", "analytic_queries")
    ]

    task6_items = []
    for i, (title, sql) in enumerate(q6, start=1):
        task6_items.append(
            {
                "id": f"task6_q{i}",
                "title": title,
                "sql": sql,
                "result_ref": f"table_preview:task6_q{i}",
            }
        )

    task7_items = []
    for i, (title, sql) in enumerate(q7, start=1):
        task7_items.append(
            {
                "id": f"task7_q{i}",
                "title": title,
                "sql": sql,
                "result_ref": f"table_preview:task7_q{i}",
            }
        )

    new_groups = []
    for g in queries["groups"]:
        new_groups.append(g)
        if g["id"] == "insert_examples":
            new_groups.append(
                {
                    "id": "sample_queries",
                    "title": "Sample queries",
                    "items": task6_items,
                }
            )
            new_groups.append(
                {
                    "id": "analytic_queries",
                    "title": "Analytical examples",
                    "items": task7_items,
                }
            )

    queries["groups"] = new_groups
    (DATA / "queries.json").write_text(json.dumps(queries, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Wrote", DATA / "queries.json", "task6:", len(task6_items), "task7:", len(task7_items))


if __name__ == "__main__":
    main()

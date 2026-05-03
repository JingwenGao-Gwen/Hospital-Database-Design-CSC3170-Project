# Hospital Database (CSC3170)

A course project implementing a **relational hospital information system** in **MySQL**: normalized schema, integrity constraints, triggers, indexes, seed data, and a **static offline web demo** to browse tables, example SQL, and query results without a backend.

## Contents

| Path | Description |
|------|-------------|
| `seed.sql` | `CREATE TABLE`, triggers, and business rules for the database |
| `index.sql` | Index definitions |
| `import_data.sql` | Bulk `INSERT` data (generated from Excel; see below) |
| `import_excel_to_mysql.py` | Reads `数据.xlsx` and regenerates `import_data.sql` |
| `task_6_queries(1).sql` / `task_7_queries(1).sql` | Sample operational and analytical SQL |
| `hospital_*.mmd` / `hospital_*.html` / `hospital_*.md` | ER diagram and relational schema documentation |
| `webDemonstration/` | Offline demo site (`webDemonstration.html` + embedded JSON) |
| `updated_hospital_web.html` | Clinical SIMS-style shell; **Engineer** opens the demo below with `?portal=1` |

## Public demo (canonical “original” web page)

Use these links in reports, assignments, or anywhere you need a **stable URL** to the **main SQL / ER demonstration** (same page as opening `webDemonstration/webDemonstration.html` locally).

| Purpose | URL |
|--------|-----|
| **GitHub Pages** (recommended in browser) | [Open the demo](https://jingwengao-gwen.github.io/Hospital-Database-Design-CSC3170-Project/webDemonstration/webDemonstration.html) |
| **Raw HTML** (for `fetch`, mirrors, or tools that need a direct file URL) | `https://raw.githubusercontent.com/JingwenGao-Gwen/Hospital-Database-Design-CSC3170-Project/main/webDemonstration/webDemonstration.html` |
| **SIMS shell** (optional; links into the same demo) | [Open SIMS](https://jingwengao-gwen.github.io/Hospital-Database-Design-CSC3170-Project/updated_hospital_web.html) → **Engineer** |

> **GitHub Pages:** In the repo on GitHub, use **Settings → Pages → Build and deployment → Branch `main` / (root)** so the `github.io` links above resolve. Until Pages is enabled, clone the repo and open the HTML files locally, or use the raw URL only where a single-file view is enough.

## Requirements

- **MySQL 8.x** (to load `seed.sql`, `index.sql`, `import_data.sql`)
- **Python 3.10+** (optional, to regenerate SQL from Excel)
  - `pip install openpyxl pypinyin`

## Quick start (MySQL)

1. Create database and user as required by your course.
2. Run in order:

   ```sql
   SOURCE seed.sql;
   SOURCE index.sql;
   SOURCE import_data.sql;
   ```

3. Open `task_6_queries(1).sql` / `task_7_queries(1).sql` in MySQL Workbench and execute.

> **Tip:** Queries that use `LIMIT` without `ORDER BY` may return different row order on different machines. Add `ORDER BY` on a primary key or date if you need deterministic output.

## Regenerate `import_data.sql` from Excel

Place **`数据.xlsx`** in the same folder as `import_excel_to_mysql.py`, then:

```bash
python import_excel_to_mysql.py
```

This overwrites `import_data.sql` and writes `import_report.txt` (fixes applied during import).

## Offline web demonstration

Open **`webDemonstration/webDemonstration.html`** in a browser (double‑click is OK), or use the **Public demo** links above when the project is hosted on GitHub Pages.

**`updated_hospital_web.html`** (repo root): clinical dashboard UI; click **Engineer** to jump to `webDemonstration.html?portal=1` (full original demo). **Hospital Portal** in the demo top bar returns to the SIMS page.

- **Relations**: table column overview + `CREATE TABLE` / constraint notes  
- **Queries**: example SQL + cached result grids (from `webDemonstration/data/tables_preview.json`)

To refresh demo data after changing `import_data.sql`:

```bash
python webDemonstration/generate_static_data.py
python webDemonstration/compute_task67_results.py
python webDemonstration/refresh_embedded_html.py
```

`refresh_embedded_html.py` re-embeds JSON into `webDemonstration.html` for offline `file://` use.

## Project structure (overview)

```
├── seed.sql
├── index.sql
├── import_data.sql
├── import_excel_to_mysql.py
├── task_6_queries(1).sql
├── task_7_queries(1).sql
├── hospital_er_diagram.mmd
├── hospital_relational_schema.html
├── updated_hospital_web.html
├── webDemonstration/
│   ├── webDemonstration.html   # main offline page
│   ├── app.js
│   ├── styles.css
│   ├── data/
│   │   ├── tables_preview.json
│   │   ├── queries.json
│   │   └── schema_and_rules.json
│   ├── generate_static_data.py
│   ├── compute_task67_results.py
│   ├── refresh_embedded_html.py
│   └── vendor/mermaid.min.js
└── README.md
```

## License / course use

This repository is submitted for **CSC3170**.  

## Authors

- Group members:
  - Jingwen Gao 123090121@link.cuhk.edu.cn
  - Su Zhang 123090824@link.cuhk.edu.cn
  - Hio CHeng Ho 1155206721@link.cuhk.edu.cn
  - Yuxuan Gong 122090130@link.cuhk.edu.cn
  - Jingyang Wang 122090528@link.cuhk.edu.cn
  - Chung Yi CHEUNG 1155211798@link.cuhk.edu.cn

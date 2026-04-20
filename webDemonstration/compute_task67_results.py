"""
Compute Task 6 / Task 7 query results from data/tables_preview.json (no MySQL).
Uses reference date 2026-04-19 for age-based queries so static demo is reproducible.
Run from repo root: python webDemonstration/compute_task67_results.py
"""

from __future__ import annotations

import json
import math
from datetime import date, datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data"
TABLES_PATH = DATA / "tables_preview.json"
REF_DATE = date(2026, 4, 19)


def load_tables() -> dict:
    return json.loads(TABLES_PATH.read_text(encoding="utf-8"))


def table_rows(tables: dict, name: str) -> list[dict]:
    t = tables["tables"][name]
    cols = t["columns"]
    return [dict(zip(cols, row)) for row in t["rows"]]


def as_result(columns: list[str], rows: list[list]) -> dict:
    return {"columns": columns, "rows": rows}


def q6_1(tables: dict) -> dict:
    patients = sorted(table_rows(tables, "patients"), key=lambda p: p["patient_id"])
    pec = {r["pec_id"]: r for r in table_rows(tables, "patient_emergency_contact")}
    out = []
    for p in patients:
        if p["pec_id"] not in pec:
            continue
        c = pec[p["pec_id"]]
        out.append(
            [
                p["first_name"],
                p["last_name"],
                p["allergies"],
                c["first_name"],
                c["phone"],
            ]
        )
        if len(out) >= 5:
            break
    return as_result(
        ["first_name", "last_name", "allergies", "contact_name", "contact_phone"],
        out,
    )


def q6_2(tables: dict) -> dict:
    patients = table_rows(tables, "patients")
    prov = {r["province_id"]: r["province_name"] for r in table_rows(tables, "provinces")}
    counts: dict[str, int] = {}
    for p in patients:
        pid = p["province_id"]
        name = prov.get(pid, pid)
        counts[name] = counts.get(name, 0) + 1
    ranked = sorted(counts.items(), key=lambda x: (-x[1], x[0]))[:5]
    return as_result(
        ["province_name", "patient_count"],
        [[n, c] for n, c in ranked],
    )


def q6_3(tables: dict) -> dict:
    admissions = {r["admission_id"]: r for r in table_rows(tables, "admissions")}
    patients = {r["patient_id"]: r for r in table_rows(tables, "patients")}
    discharges = sorted(table_rows(tables, "discharges"), key=lambda d: d["admission_id"])
    out = []
    for d in discharges:
        if d["discharge_status"] != "R":
            continue
        adm_id = d["admission_id"]
        a = admissions.get(adm_id)
        if not a:
            continue
        p = patients.get(a["patient_id"])
        if not p:
            continue
        out.append(
            [
                p["first_name"],
                p["last_name"],
                a["admission_date"],
                d["discharge_date"],
                d["discharge_status"],
            ]
        )
        if len(out) >= 5:
            break
    return as_result(
        ["first_name", "last_name", "admission_date", "discharge_date", "discharge_status"],
        out,
    )


def q6_4(tables: dict) -> dict:
    tl = sorted(table_rows(tables, "treatment_log"), key=lambda r: r["log_id"])
    admissions = {r["admission_id"]: r for r in table_rows(tables, "admissions")}
    patients = {r["patient_id"]: r for r in table_rows(tables, "patients")}
    depts = {r["dept_id"]: r["dept_name"] for r in table_rows(tables, "departments")}
    out = []
    for row in tl:
        a = admissions.get(row["admission_id"])
        if not a:
            continue
        p = patients.get(a["patient_id"])
        if not p:
            continue
        dept_name = depts.get(row["to_dept_id"], row["to_dept_id"])
        out.append([p["last_name"], a["diagnosis"], row["exam_date"], dept_name])
        if len(out) >= 5:
            break
    return as_result(["last_name", "diagnosis", "transfer_date", "transferred_to"], out)


def q6_5(tables: dict) -> dict:
    admissions = table_rows(tables, "admissions")
    doctors = table_rows(tables, "doctors")
    counts: dict[int, int] = {}
    for a in admissions:
        did = a["attending_doctor_id"]
        counts[did] = counts.get(did, 0) + 1
    ranked_docs = sorted(counts.items(), key=lambda x: (-x[1], x[0]))[:3]
    doc_by_id = {d["doctor_id"]: d for d in doctors}
    out = []
    for did, cnt in ranked_docs:
        d = doc_by_id[did]
        out.append([d["last_name"], d["speciality"], cnt])
    return as_result(["doctor_name", "speciality", "total_admissions_handled"], out)


def q6_6(tables: dict) -> dict:
    admissions = table_rows(tables, "admissions")
    patients = {r["patient_id"]: r for r in table_rows(tables, "patients")}
    out = []
    for a in admissions:
        if int(a["diag_severity"]) < 4:
            continue
        p = patients.get(a["patient_id"])
        if not p or not p.get("allergies"):
            continue
        if "penicillin" not in str(p["allergies"]).lower():
            continue
        out.append(
            [
                p["first_name"],
                p["last_name"],
                p["allergies"],
                a["diagnosis"],
                a["diag_severity"],
            ]
        )
    return as_result(
        ["first_name", "last_name", "allergies", "diagnosis", "diag_severity"],
        out,
    )


def doctor_level(years: int) -> str:
    if years < 5:
        return "Junior"
    if 5 <= years <= 15:
        return "Intermediate"
    return "Senior"


def q7_1(tables: dict) -> dict:
    """Match task_7 SQL: one row per (experience_level, predicted_class) where class frequency equals max."""
    admissions = table_rows(tables, "admissions")
    doctors = {d["doctor_id"]: d for d in table_rows(tables, "doctors")}
    discharges = {d["admission_id"]: d for d in table_rows(tables, "discharges")}
    cd: list[dict] = []
    for a in admissions:
        dis = discharges.get(a["admission_id"])
        if not dis or dis.get("discharge_status") is None:
            continue
        dr = doctors.get(a["attending_doctor_id"])
        if not dr:
            continue
        y = int(dr["years_of_exp"])
        cd.append(
            {
                "item_id": a["admission_id"],
                "doctor_experience_level": doctor_level(y),
                "actual_class": dis["discharge_status"],
            }
        )
    from collections import defaultdict

    cf: dict[tuple[str, str], int] = defaultdict(int)
    for r in cd:
        cf[(r["doctor_experience_level"], r["actual_class"])] += 1
    max_c: dict[str, int] = defaultdict(int)
    for (lvl, _), c in cf.items():
        max_c[lvl] = max(max_c[lvl], c)
    rows_out = []
    for lvl in ("Junior", "Intermediate", "Senior"):
        subset = [r for r in cd if r["doctor_experience_level"] == lvl]
        n = len(subset)
        if n == 0:
            continue
        mc = max_c[lvl]
        cnt_r = sum(1 for r in subset if r["actual_class"] == "R")
        cnt_t = sum(1 for r in subset if r["actual_class"] == "T")
        cnt_d = sum(1 for r in subset if r["actual_class"] == "D")
        for cls in sorted({c for (lv, c) in cf if lv == lvl}):
            if cf.get((lvl, cls), 0) != mc:
                continue
            acc = round((mc / n) * 100, 2)
            rows_out.append([lvl, n, cnt_r, cnt_t, cnt_d, cls, acc])
    rows_out.sort(key=lambda r: (-r[6], r[0], r[5]))
    return as_result(
        [
            "doctor_experience_level",
            "total_training_cases",
            "count_Recovered_R",
            "count_Transferred_T",
            "count_Deceased_D",
            "predicted_discharge_class",
            "prediction_accuracy_pct",
        ],
        rows_out,
    )


def q7_2(tables: dict) -> dict:
    admissions = table_rows(tables, "admissions")
    patients = {r["patient_id"]: r for r in table_rows(tables, "patients")}
    total_adm = len({a["admission_id"] for a in admissions})
    pad: list[tuple[int, str, str]] = []
    for a in admissions:
        p = patients.get(a["patient_id"])
        if not p or p.get("allergies") is None:
            continue
        pad.append((a["admission_id"], str(p["allergies"]), a["diagnosis"]))
    from collections import defaultdict

    pair_counts: dict[tuple[str, str], set[int]] = defaultdict(set)
    allergy_adms: dict[str, set[int]] = defaultdict(set)
    for adm_id, alg, diag in pad:
        pair_counts[(alg, diag)].add(adm_id)
        allergy_adms[alg].add(adm_id)
    rows_out = []
    for (alg, diag), ids in pair_counts.items():
        tc = len(ids)
        if tc < 3:
            continue
        sup = round(tc * 100.0 / total_adm, 2) if total_adm else 0.0
        denom = len(allergy_adms[alg])
        conf = round(tc * 100.0 / denom, 2) if denom else 0.0
        rows_out.append([alg, diag, tc, sup, conf])
    rows_out.sort(key=lambda r: (-r[4], -r[3]))
    return as_result(
        ["antecedent_allergy", "consequent_diagnosis", "transaction_count", "support_pct", "confidence_pct"],
        rows_out,
    )


def parse_date(d) -> date | None:
    if d is None:
        return None
    if isinstance(d, date) and not isinstance(d, datetime):
        return d
    s = str(d)
    if isinstance(d, (int, float)):
        return None
    for fmt in ("%Y-%m-%d", "%Y/%m/%d"):
        try:
            return datetime.strptime(s[:10], fmt).date()
        except ValueError:
            continue
    return None


def age_at(birth, ref: date) -> int:
    b = parse_date(birth)
    if not b:
        return 0
    a = ref.year - b.year - ((ref.month, ref.day) < (b.month, b.day))
    return max(0, a)


def q7_3(tables: dict) -> dict:
    patients = table_rows(tables, "patients")
    clusters: dict[str, list[int]] = {
        "Cluster 1: Minor (0–17)": [],
        "Cluster 2: Younger Adult (18–44)": [],
        "Cluster 3: Middle-Aged (45–64)": [],
        "Cluster 4: Senior (65+)": [],
    }
    for p in patients:
        pa = age_at(p["birth_date"], REF_DATE)
        if pa <= 17:
            k = "Cluster 1: Minor (0–17)"
        elif 18 <= pa <= 44:
            k = "Cluster 2: Younger Adult (18–44)"
        elif 45 <= pa <= 64:
            k = "Cluster 3: Middle-Aged (45–64)"
        else:
            k = "Cluster 4: Senior (65+)"
        clusters[k].append(pa)
    rows_out = []
    order = list(clusters.keys())
    for k in order:
        ages = clusters[k]
        if not ages:
            continue
        mean_age = round(sum(ages) / len(ages), 1)
        mn, mx = min(ages), max(ages)
        m = sum(ages) / len(ages)
        var = sum((x - m) ** 2 for x in ages) / len(ages)
        std = round(math.sqrt(var), 2)
        rows_out.append([k, len(ages), mean_age, mn, mx, std])
    rows_out.sort(key=lambda r: r[2])
    return as_result(
        [
            "age_cluster",
            "total_patients",
            "cluster_center_avg_age",
            "min_age",
            "max_age",
            "within_cluster_variation",
        ],
        rows_out,
    )


def q7_4(tables: dict) -> dict:
    admissions = table_rows(tables, "admissions")
    patients = {r["patient_id"]: r for r in table_rows(tables, "patients")}
    discharges_list = table_rows(tables, "discharges")
    dis_by_adm = {d["admission_id"]: d for d in discharges_list}
    rows_f = []
    for a in admissions:
        d = dis_by_adm.get(a["admission_id"])
        if not d:
            continue
        p = patients.get(a["patient_id"])
        if not p:
            continue
        h, w = p.get("height"), p.get("weight")
        if h is None or w is None or float(h) <= 0:
            continue
        adm_d = parse_date(a["admission_date"])
        dis_d = parse_date(d["discharge_date"])
        if not adm_d or not dis_d:
            continue
        los = (dis_d - adm_d).days
        age = age_at(p["birth_date"], dis_d)
        bmi = round(float(w) / ((float(h) / 100.0) ** 2), 2)
        sev = int(a["diag_severity"])
        alg = 1 if (p.get("allergies") not in (None, "")) else 0
        rows_f.append((los, age, bmi, sev, alg))
    n = len(rows_f)
    if n == 0:
        return as_result(
            [
                "total_samples",
                "beta_0_intercept",
                "beta_1_age",
                "beta_2_bmi",
                "beta_3_severity",
                "beta_4_allergies",
                "avg_los",
            ],
            [],
        )

    def col(j):
        return [r[j] for r in rows_f]

    y = col(0)
    x1, x2, x3, x4 = col(1), col(2), col(3), col(4)
    avg_y = sum(y) / n
    avg_x1 = sum(x1) / n
    avg_x2 = sum(x2) / n
    avg_x3 = sum(x3) / n
    avg_x4 = sum(x4) / n
    sum_y = sum(y)
    sum_x1 = sum(x1)
    sum_x2 = sum(x2)
    sum_x3 = sum(x3)
    sum_x4 = sum(x4)
    sum_x1y = sum(x1[i] * y[i] for i in range(n))
    sum_x2y = sum(x2[i] * y[i] for i in range(n))
    sum_x3y = sum(x3[i] * y[i] for i in range(n))
    sum_x4y = sum(x4[i] * y[i] for i in range(n))
    sum_x1sq = sum(v * v for v in x1)
    sum_x2sq = sum(v * v for v in x2)
    sum_x3sq = sum(v * v for v in x3)
    sum_x4sq = sum(v * v for v in x4)

    def slope(sxy, sx, sy, sxsq, n_):
        den = sxsq - (sx * sx) / n_
        if den == 0:
            return 0.0
        return (sxy - sx * sy / n_) / den

    b1 = slope(sum_x1y, sum_x1, sum_y, sum_x1sq, n)
    b2 = slope(sum_x2y, sum_x2, sum_y, sum_x2sq, n)
    b3 = slope(sum_x3y, sum_x3, sum_y, sum_x3sq, n)
    b4 = slope(sum_x4y, sum_x4, sum_y, sum_x4sq, n)
    b0 = (
        avg_y
        - avg_x1 * b1
        - avg_x2 * b2
        - avg_x3 * b3
        - avg_x4 * b4
    )
    row = [
        n,
        round(b0, 4),
        round(b1, 4),
        round(b2, 4),
        round(b3, 4),
        round(b4, 4),
        round(avg_y, 2),
    ]
    return as_result(
        [
            "total_samples",
            "beta_0_intercept",
            "beta_1_age",
            "beta_2_bmi",
            "beta_3_severity",
            "beta_4_allergies",
            "avg_los",
        ],
        [row],
    )


def main() -> None:
    data = load_tables()
    tables = data["tables"]
    tables["task6_q1"] = q6_1({"tables": tables})
    tables["task6_q2"] = q6_2({"tables": tables})
    tables["task6_q3"] = q6_3({"tables": tables})
    tables["task6_q4"] = q6_4({"tables": tables})
    tables["task6_q5"] = q6_5({"tables": tables})
    tables["task6_q6"] = q6_6({"tables": tables})
    tables["task7_q1"] = q7_1({"tables": tables})
    tables["task7_q2"] = q7_2({"tables": tables})
    tables["task7_q3"] = q7_3({"tables": tables})
    tables["task7_q4"] = q7_4({"tables": tables})
    TABLES_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Updated", TABLES_PATH)


if __name__ == "__main__":
    main()

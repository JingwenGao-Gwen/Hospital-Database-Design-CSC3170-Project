import re
from pathlib import Path

p = Path(r"c:\Users\Lenovo\Desktop\新建文件夹\import_data.sql")
text = p.read_text(encoding="utf-8")

m = re.search(
    r"INSERT INTO ADMISSIONS\s*\([^)]*diag_severity[^)]*\)\s*VALUES\s*\n(.*?);\s*",
    text,
    flags=re.S | re.I,
)
if not m:
    raise SystemExit("ADMISSIONS insert block not found")

block = m.group(1)

vals = []
i = 0
n = len(block)
while i < n:
    while i < n and block[i] != "(":
        i += 1
    if i >= n:
        break
    start = i
    depth = 0
    in_str = False
    while i < n:
        ch = block[i]
        if in_str:
            if ch == "'":
                if i + 1 < n and block[i + 1] == "'":
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
                    tup = block[start : i + 1]
                    inner = tup[1:-1]
                    parts = []
                    buf = ""
                    ins = False
                    j = 0
                    L = len(inner)
                    while j <= L:
                        c = inner[j] if j < L else None
                        if ins:
                            if c == "'":
                                if j + 1 < L and inner[j + 1] == "'":
                                    buf += "'"
                                    j += 2
                                    continue
                                ins = False
                                j += 1
                                continue
                            if c is None:
                                break
                            buf += c
                            j += 1
                            continue
                        else:
                            if c == "'":
                                ins = True
                                j += 1
                                continue
                            if c is None or c == ",":
                                parts.append(buf.strip())
                                buf = ""
                                j += 1
                                continue
                            buf += c
                            j += 1
                    sev = parts[-1]
                    try:
                        vals.append(int(float(sev)))
                    except Exception:
                        pass
                    i += 1
                    break
            i += 1

print("ADMISSIONS diag_severity count:", len(vals))
print("min:", min(vals), "max:", max(vals))
bad = [v for v in vals if v < 1 or v > 5]
print("outside_1_5:", len(bad))


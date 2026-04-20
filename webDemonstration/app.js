const $ = (id) => document.getElementById(id);

function escapeHtml(s) {
  return String(s)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function getEmbeddedJson(id) {
  const el = document.getElementById(id);
  if (!el) return null;
  try {
    return JSON.parse(el.textContent || "null");
  } catch (e) {
    console.error(`Embedded JSON failed to parse (#${id}):`, e);
    return null;
  }
}

function getEmbeddedText(id) {
  const el = document.getElementById(id);
  return el ? el.textContent || "" : "";
}

async function loadJson(path, embeddedId) {
  const embedded = embeddedId ? getEmbeddedJson(embeddedId) : null;
  if (embedded !== null) return embedded;
  if (location.protocol === "file:") {
    throw new Error(
      "Embedded data missing or invalid (check console). Opening via file:// cannot load ./data/*.json; use a local server or fix offline HTML."
    );
  }
  const res = await fetch(path);
  if (!res.ok) throw new Error(`Failed to load ${path}: ${res.status}`);
  return await res.json();
}

function renderTable(columns, rows) {
  const thead = `<thead><tr>${columns.map((c) => `<th>${escapeHtml(c)}</th>`).join("")}</tr></thead>`;
  const tbody = `<tbody>${rows
    .map(
      (r) =>
        `<tr>${r
          .map((v) => `<td>${v === null ? `<span class="muted">NULL</span>` : `<code>${escapeHtml(v)}</code>`}</td>`)
          .join("")}</tr>`
    )
    .join("")}</tbody>`;
  return `<table>${thead}${tbody}</table>`;
}

function renderPaginatedTable(columns, rows, pageSize = 10) {
  const total = rows.length;
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const state = { page: 1 };
  const containerId = `pg_${Math.random().toString(16).slice(2)}`;

  function pageSlice(p) {
    const start = (p - 1) * pageSize;
    const end = Math.min(total, start + pageSize);
    return { start, end, rows: rows.slice(start, end) };
  }

  function pagesToShow() {
    // Show: 1 ... p-2 p-1 p p+1 p+2 ... last
    const p = state.page;
    const set = new Set([1, totalPages, p - 2, p - 1, p, p + 1, p + 2]);
    const nums = [...set].filter((n) => n >= 1 && n <= totalPages).sort((a, b) => a - b);
    const out = [];
    let prev = 0;
    for (const n of nums) {
      if (prev && n - prev > 1) out.push("…");
      out.push(n);
      prev = n;
    }
    return out;
  }

  function render() {
    const { start, end, rows: slice } = pageSlice(state.page);
    const left = `Showing ${start + 1}–${end} of ${total} rows`;
    const btns = pagesToShow()
      .map((x) => {
        if (x === "…") return `<span class="muted" style="padding:6px 6px">…</span>`;
        const n = x;
        const cls = n === state.page ? "pageBtn active" : "pageBtn";
        return `<button class="${cls}" data-page="${n}">${n}</button>`;
      })
      .join("");

    return `
      <div class="pager">
        <div class="pagerLeft">${escapeHtml(left)}</div>
        <div class="pagerBtns">
          <button class="pageBtn" data-nav="prev" ${state.page === 1 ? "disabled" : ""}>Prev</button>
          ${btns}
          <button class="pageBtn" data-nav="next" ${state.page === totalPages ? "disabled" : ""}>Next</button>
        </div>
      </div>
      ${renderTable(columns, slice)}
    `;
  }

  function attach() {
    const host = document.getElementById(containerId);
    if (!host) return;
    host.addEventListener("click", (e) => {
      const t = e.target;
      if (!(t instanceof HTMLElement)) return;
      const nav = t.getAttribute("data-nav");
      const page = t.getAttribute("data-page");
      if (nav === "prev" && state.page > 1) state.page -= 1;
      else if (nav === "next" && state.page < totalPages) state.page += 1;
      else if (page) state.page = Math.max(1, Math.min(totalPages, Number(page)));
      else return;
      host.innerHTML = render();
    });
  }

  const html = `<div id="${containerId}">${render()}</div>`;
  return { html, attach };
}

function renderExpected(expected) {
  if (!expected) return `<div class="muted">No result</div>`;
  if (expected.type === "ok") {
    return `
      <div class="status"><span class="dot ok"></span>OK</div>
      <div class="msg">${escapeHtml(expected.message || "")}</div>
    `;
  }
  if (expected.type === "error") {
    return `
      <div class="status"><span class="dot err"></span>Error</div>
      <div class="msg"><code>Error Code: ${escapeHtml(expected.code)}</code> ${escapeHtml(expected.message || "")}</div>
    `;
  }
  return `<div class="muted">Unknown expected result</div>`;
}

function renderSchema(seedSchema, tableName) {
  const lowers = tableName.toLowerCase();
  const blocks = seedSchema?.create_tables_sql || [];
  const match = blocks.find((b) => b.toLowerCase().startsWith(`create table ${lowers}`));
  const triggerMessages = seedSchema?.trigger_messages || [];
  const msgs = triggerMessages
    .map((m) => `<li><code>${escapeHtml(m)}</code></li>`)
    .join("");

  return `
    <div class="muted" style="margin-bottom:10px">CREATE TABLE</div>
    <pre>${escapeHtml(match || "N/A")}</pre>
    <div class="muted" style="margin:12px 0 6px">Possible trigger error messages</div>
    <ul style="margin:0; padding-left:18px">${msgs}</ul>
  `;
}

function setSchemaPanelVisible(visible) {
  const el = $("schemaSection");
  if (el) el.hidden = !visible;
}

function setQueriesPanelVisible(visible) {
  const el = $("queriesPanel");
  if (el) el.hidden = !visible;
}

function setSqlPanelVisible(visible) {
  const el = $("sqlSection");
  if (el) el.hidden = !visible;
}

function buildMenu(queries, onSelect) {
  const root = document.createElement("div");
  for (const g of queries.groups) {
    const group = document.createElement("div");
    group.className = "menuGroup";
    const title = document.createElement("div");
    title.className = "menuGroupTitle";
    title.textContent = g.title;
    group.appendChild(title);
    for (const item of g.items) {
      const btn = document.createElement("button");
      btn.className = "menuItem";
      btn.dataset.itemId = item.id;
      const pillMap = {
        select_all: "SELECT",
        insert_examples: "INSERT",
        sample_queries: "SAMPLE",
        analytic_queries: "ANALYT",
      };
      const pill = pillMap[g.id] ?? g.id.replace(/_/g, " ").toUpperCase();
      btn.innerHTML = `<span class="pill">${escapeHtml(pill)}</span><span>${escapeHtml(item.title)}</span>`;
      btn.addEventListener("click", () => onSelect(item, btn));
      group.appendChild(btn);
    }
    root.appendChild(group);
  }
  return root;
}

function parseCreateTable(seedSchema, tableName) {
  const lowers = tableName.toLowerCase();
  const blocks = seedSchema?.create_tables_sql || [];
  const sql = blocks.find((b) => b.toLowerCase().startsWith(`create table ${lowers}`)) || "";
  const lines = sql.split(/\r?\n/);

  const columns = [];
  const fkCols = new Set();
  const pkCols = new Set();

  for (const ln of lines) {
    const m = ln.match(/FOREIGN KEY\s*\(([^)]+)\)/i);
    if (m) {
      const col = m[1].trim().replace(/`/g, "");
      if (col) fkCols.add(col);
    }
  }
  for (const ln of lines) {
    const m = ln.match(/PRIMARY KEY\s*\(([^)]+)\)/i);
    if (m) {
      for (const c of m[1].split(",")) pkCols.add(c.trim().replace(/`/g, ""));
    }
  }

  for (const ln of lines) {
    const t = ln.trim();
    if (!t || t.startsWith("CREATE TABLE") || t.startsWith(");")) continue;
    if (t.toUpperCase().startsWith("CONSTRAINT") || t.toUpperCase().startsWith("PRIMARY KEY") || t.toUpperCase().startsWith("FOREIGN KEY")) continue;
    const m = t.match(/^`?([A-Za-z_][A-Za-z0-9_]*)`?\s+([^,]+),?$/);
    if (!m) continue;
    const name = m[1];
    const rest = m[2].trim();
    const type = rest.split(/\s+(?=NOT|NULL|CHECK|DEFAULT|UNIQUE|PRIMARY|REFERENCES|COMMENT|AUTO_INCREMENT)/i)[0].trim();
    const inlinePk = /\bPRIMARY\s+KEY\b/i.test(rest);
    columns.push({
      name,
      type,
      pk: inlinePk || pkCols.has(name),
      fk: fkCols.has(name),
    });
  }
  return { sql, columns };
}

function renderRelationalSchema(tableName, parsed) {
  const cols = parsed?.columns || [];
  const rows = cols
    .map((c) => {
      const key = c.pk ? "🔑" : c.fk ? "🔗" : "";
      return `<tr><td style="width:48px">${key}</td><td><code>${escapeHtml(c.name)}</code></td><td><code>${escapeHtml(c.type)}</code></td></tr>`;
    })
    .join("");
  return `
    <div class="muted" style="margin-bottom:10px">${escapeHtml(tableName.toUpperCase())}</div>
    <table>
      <thead><tr><th style="width:48px">Key</th><th>Column</th><th>Data type</th></tr></thead>
      <tbody>${rows || `<tr><td colspan="3" class="muted">No schema found</td></tr>`}</tbody>
    </table>
  `;
}

function parseResultRef(ref) {
  // "table_preview:patients"
  if (!ref) return null;
  const [kind, name] = ref.split(":");
  return { kind, name };
}

function buildRelationsList(tables, onPick) {
  const names = Object.keys(tables || {})
    .filter((n) => !/^task[67]_q\d+$/i.test(n))
    .sort((a, b) => a.localeCompare(b));
  const root = document.createElement("div");
  for (const n of names) {
    const meta = tables[n];
    const cols = meta?.columns?.length ?? 0;
    const rows = meta?.rows?.length ?? 0;
    const btn = document.createElement("button");
    btn.className = "relationItem";
    btn.dataset.rel = n;
    btn.innerHTML = `<span>${escapeHtml(n.toUpperCase())}</span><span class="relationMeta">${cols} cols • ${rows} rows</span>`;
    btn.addEventListener("click", () => onPick(n, btn));
    root.appendChild(btn);
  }
  return root;
}

function setupErFullscreen() {
  const modal = $("erModal");
  const body = $("erModalBody");
  const close = $("erModalClose");
  const backdrop = $("erModalBackdrop");
  const fullBtn = $("erFullBtn");
  const erBox = $("erBox");

  function open() {
    // clone current rendered ER (SVG)
    body.innerHTML = "";
    const svg = erBox.querySelector("svg");
    if (svg) body.appendChild(svg.cloneNode(true));
    else body.textContent = erBox.textContent || "ER diagram not available.";
    modal.classList.remove("hidden");
    modal.setAttribute("aria-hidden", "false");
  }
  function closeIt() {
    modal.classList.add("hidden");
    modal.setAttribute("aria-hidden", "true");
  }
  fullBtn?.addEventListener("click", open);
  erBox?.addEventListener("dblclick", open);
  close?.addEventListener("click", closeIt);
  backdrop?.addEventListener("click", closeIt);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeIt();
  });
}

async function main() {
  mermaid.initialize({ startOnLoad: false, theme: "dark" });

  const [queries, previews, seedSchema, erText] = await Promise.all([
    loadJson("./data/queries.json", "embedded-queries"),
    loadJson("./data/tables_preview.json", "embedded-tables"),
    loadJson("./data/schema_and_rules.json", "embedded-schema"),
    (async () => {
      const embedded = getEmbeddedText("embedded-er");
      if (embedded) return embedded;
      const res = await fetch("./er_diagram.mmd");
      return await res.text();
    })(),
  ]);

  $("erBox").textContent = erText;
  try {
    await mermaid.run({ querySelector: ".mermaid" });
  } catch (e) {
    console.error(e);
    $("erBox").textContent = "ER diagram failed to render. Check mermaid text / loading path.";
  }
  setupErFullscreen();

  // Theme selector (full-page background + surfaces via CSS variables)
  const themeSelect = $("themeSelect");
  const allowedThemes = new Set(["midnight", "light", "ocean", "sunset", "lavender"]);
  let stored = localStorage.getItem("hospital_theme") || "midnight";
  if (!allowedThemes.has(stored)) stored = "midnight";
  document.documentElement.setAttribute("data-theme", stored);
  if (themeSelect) {
    themeSelect.value = stored;
    themeSelect.addEventListener("change", () => {
      const v = themeSelect.value || "midnight";
      document.documentElement.setAttribute("data-theme", v);
      localStorage.setItem("hospital_theme", v);
    });
  }

  let activeBtn = null;
  let activeRelBtn = null;

  const menuEl = buildMenu(queries, (item, btn) => {
    if (activeRelBtn) {
      activeRelBtn.classList.remove("active");
      activeRelBtn = null;
    }
    if (activeBtn) activeBtn.classList.remove("active");
    activeBtn = btn;
    activeBtn.classList.add("active");

    setSchemaPanelVisible(false);
    setQueriesPanelVisible(true);
    setSqlPanelVisible(true);

    $("sqlText").textContent = item.sql || "";

    if (item.result_ref) {
      const rr = parseResultRef(item.result_ref);
      if (rr?.kind === "table_preview") {
        const t = previews?.tables?.[rr.name];
        if (!t) {
          $("resultBox").innerHTML = `<div class="muted">No data for ${escapeHtml(rr.name)}</div>`;
        } else {
          const rendered = renderPaginatedTable(t.columns, t.rows, 10);
          $("resultBox").innerHTML = rendered.html;
          if (rendered.attach) rendered.attach();
        }
        return;
      }
    }

    $("resultBox").innerHTML = renderExpected(item.expected);
  });

  const menuHost = $("menu");
  menuHost.innerHTML = "";
  menuHost.appendChild(menuEl);

  // Relations: column overview in Result; CREATE TABLE + trigger hints in Schema / Constraints
  const relHost = $("relations");
  if (relHost) {
    relHost.innerHTML = "";
    const relEl = buildRelationsList(previews?.tables, (name, btn) => {
      if (activeBtn) {
        activeBtn.classList.remove("active");
        activeBtn = null;
      }
      if (activeRelBtn) activeRelBtn.classList.remove("active");
      activeRelBtn = btn;
      activeRelBtn.classList.add("active");

      setQueriesPanelVisible(false);
      setSchemaPanelVisible(true);
      setSqlPanelVisible(false);

      $("sqlText").textContent = `SELECT * FROM ${name};`;
      const parsed = parseCreateTable(seedSchema, name);
      $("resultBox").innerHTML = renderRelationalSchema(name, parsed);
      $("schemaBox").innerHTML = renderSchema(seedSchema, name);
    });
    relHost.appendChild(relEl);
  }

  // default select first item
  const firstBtn = menuHost.querySelector(".menuItem");
  if (firstBtn) firstBtn.click();
}

main().catch((e) => {
  console.error(e);
  $("resultBox").innerHTML = `<div class="status"><span class="dot err"></span>Error</div><div class="msg">${escapeHtml(e.message)}</div>`;
});


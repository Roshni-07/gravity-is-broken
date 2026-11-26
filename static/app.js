const elements = Object.fromEntries(
  [
    "net-total", "income-total", "expense-total", "transaction-count",
    "transaction-rows", "empty-state", "entry-form", "entry-description",
    "entry-amount", "entry-date", "entry-type", "app-notice", "search-input",
    "type-filter", "statement-file", "import-panel", "import-filename",
    "map-date", "map-description", "map-amount", "map-type", "import-message",
    "preview-wrap", "preview-body", "skip-duplicates", "confirm-import-button",
  ].map((id) => [id, document.getElementById(id)]),
);

let transactions = [];
let totals = { income_paise: "0", expense_paise: "0", net_paise: "0" };
let stagedImport = null;
let previewRequest = 0;

async function apiRequest(path, body) {
  const options = { method: body === undefined ? "GET" : "POST" };
  if (body !== undefined) {
    options.headers = {
      "Content-Type": "application/json",
      "X-Requested-With": "RupeeLedger",
    };
    options.body = JSON.stringify(body);
  }
  const response = await fetch(path, options);
  let payload;
  try {
    payload = await response.json();
  } catch {
    throw new Error("The local app returned an unreadable response. Restart it and try again.");
  }
  if (!response.ok) {
    throw new Error(payload.error || `The local app returned status ${response.status}.`);
  }
  return payload;
}

function showNotice(message, kind = "success") {
  const notice = elements["app-notice"];
  notice.textContent = message;
  notice.dataset.kind = kind;
  notice.hidden = false;
}

function hideNotice() {
  elements["app-notice"].hidden = true;
}

function makeElement(tag, className, text) {
  const element = document.createElement(tag);
  if (className) element.className = className;
  if (text !== undefined) element.textContent = text;
  return element;
}

function formatPaise(value) {
  const paise = BigInt(value);
  const negative = paise < 0n;
  const absolute = negative ? -paise : paise;
  const rupees = absolute / 100n;
  const fraction = String(absolute % 100n).padStart(2, "0");
  const grouped = new Intl.NumberFormat("en-IN", {
    maximumFractionDigits: 0,
  }).format(Number(rupees));
  return `${negative ? "−" : ""}₹${grouped}.${fraction}`;
}

function formatDate(value) {
  return new Intl.DateTimeFormat("en-IN", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${value}T00:00:00Z`));
}

function transactionFingerprint(transaction) {
  return [
    transaction.date,
    transaction.type,
    transaction.amount_paise,
    transaction.description.trim().toLocaleLowerCase("en-IN"),
  ].join("\u0000");
}

function render() {
  elements["net-total"].textContent = formatPaise(totals.net_paise);
  elements["income-total"].textContent = formatPaise(totals.income_paise);
  elements["expense-total"].textContent = formatPaise(totals.expense_paise);
  elements["transaction-count"].textContent = String(transactions.length);

  const search = elements["search-input"].value.trim().toLocaleLowerCase("en-IN");
  const typeFilter = elements["type-filter"].value;
  const visible = transactions
    .filter((transaction) => typeFilter === "all" || transaction.type === typeFilter)
    .filter((transaction) => transaction.description.toLocaleLowerCase("en-IN").includes(search))
    .sort((left, right) => right.date.localeCompare(left.date) || right.id.localeCompare(left.id));

  elements["transaction-rows"].replaceChildren();
  for (const transaction of visible) {
    const row = document.createElement("tr");
    row.append(
      makeElement("td", "", formatDate(transaction.date)),
      makeElement("td", "", transaction.description),
      makeElement("td"),
      makeElement("td"),
      makeElement(
        "td",
        `amount-cell ${transaction.type === "credit" ? "money-in" : "money-out"}`,
        `${transaction.type === "credit" ? "+" : "−"}${formatPaise(transaction.amount_paise)}`,
      ),
    );
    row.children[2].append(makeElement(
      "span",
      "source-tag",
      transaction.source === "csv" ? "CSV import" : "Manual",
    ));
    row.children[3].append(makeElement(
      "span",
      `type-tag ${transaction.type}`,
      transaction.type === "credit" ? "Money in" : "Money out",
    ));
    elements["transaction-rows"].append(row);
  }

  elements["empty-state"].hidden = visible.length > 0 || transactions.length > 0;
  if (transactions.length > 0 && visible.length === 0) {
    const row = document.createElement("tr");
    const cell = makeElement("td", "", "No transactions match these filters.");
    cell.colSpan = 5;
    row.append(cell);
    elements["transaction-rows"].append(row);
  }
}

async function refreshLedger() {
  const [transactionResult, summary] = await Promise.all([
    apiRequest("/api/transactions"),
    apiRequest("/api/summary"),
  ]);
  transactions = transactionResult.transactions;
  totals = summary;
  render();
}

function openEntryForm() {
  const now = new Date();
  const today = [
    now.getFullYear(),
    String(now.getMonth() + 1).padStart(2, "0"),
    String(now.getDate()).padStart(2, "0"),
  ].join("-");
  elements["entry-date"].value = today;
  elements["entry-form"].hidden = false;
  elements["entry-description"].focus();
}

function setImportMessage(message, kind = "success") {
  elements["import-message"].textContent = message;
  elements["import-message"].dataset.kind = kind;
}

const columnDefinitions = [
  { key: "date", id: "map-date", match: /date|time/i, optional: false },
  { key: "description", id: "map-description", match: /description|details|narration|merchant|remarks|particulars/i, optional: false },
  { key: "amount", id: "map-amount", match: /amount|value|debit|credit/i, optional: false },
  { key: "type", id: "map-type", match: /type|dr.?cr|direction/i, optional: true },
];

function addColumnOptions(headers) {
  for (const definition of columnDefinitions) {
    const select = elements[definition.id];
    select.replaceChildren();
    if (definition.optional) {
      const option = makeElement("option", "", "Infer from signed amount");
      option.value = "";
      select.append(option);
    }
    headers.forEach((header, index) => {
      const option = makeElement("option", "", header.trim() || `Column ${index + 1}`);
      option.value = String(index);
      select.append(option);
    });
    const matchIndex = headers.findIndex((header) => definition.match.test(header));
    if (matchIndex >= 0) select.value = String(matchIndex);
  }
}

function getColumnMapping() {
  return {
    date: Number(elements["map-date"].value),
    description: Number(elements["map-description"].value),
    amount: Number(elements["map-amount"].value),
    type: elements["map-type"].value === "" ? null : Number(elements["map-type"].value),
  };
}

async function renderImportPreview() {
  if (!stagedImport) return;
  const requestNumber = ++previewRequest;
  elements["confirm-import-button"].disabled = true;
  setImportMessage("Checking the selected columns locally…");

  try {
    const result = await apiRequest("/api/import/preview", {
      csv_text: stagedImport.csvText,
      columns: getColumnMapping(),
    });
    if (requestNumber !== previewRequest || !stagedImport) return;
    stagedImport.review = result;

    const existing = new Set(transactions.map(transactionFingerprint));
    const seen = new Set(existing);
    elements["preview-body"].replaceChildren();
    const samples = result.transactions.slice(0, 8);
    for (const transaction of samples) {
      const fingerprint = transactionFingerprint(transaction);
      const duplicate = seen.has(fingerprint);
      seen.add(fingerprint);
      const row = document.createElement("tr");
      row.append(
        makeElement("td", "", formatDate(transaction.date)),
        makeElement("td", "", transaction.description),
        makeElement("td", "", transaction.type === "credit" ? "Money in" : "Money out"),
        makeElement(
          "td",
          `amount-cell ${transaction.type === "credit" ? "money-in" : "money-out"}`,
          `${transaction.type === "credit" ? "+" : "−"}${formatPaise(transaction.amount_paise)}`,
        ),
        makeElement("td", duplicate ? "match-warning" : "", duplicate ? "Exact match" : "New entry"),
      );
      elements["preview-body"].append(row);
    }
    elements["preview-wrap"].hidden = samples.length === 0;

    const validCount = result.transactions.length;
    const duplicateCount = result.duplicate_count;
    const importCount = Math.max(0, validCount - (
      elements["skip-duplicates"].checked ? duplicateCount : 0
    ));
    const parts = [
      `${validCount} valid row${validCount === 1 ? "" : "s"}`,
      `${importCount} will be added`,
    ];
    if (duplicateCount > 0) {
      parts.push(
        `${duplicateCount} exact match${duplicateCount === 1 ? "" : "es"}`
        + (elements["skip-duplicates"].checked ? " will be skipped" : " flagged"),
      );
    }
    if (result.errors.length > 0) {
      parts.push(`${result.errors.length} row${result.errors.length === 1 ? "" : "s"} will not be imported`);
    }
    if (validCount > samples.length) parts.push(`showing ${samples.length} of ${validCount} valid rows`);
    const errorDetails = result.errors
      .slice(0, 3)
      .map((error) => `Row ${error.line}: ${error.message}`)
      .join("\n");
    setImportMessage([parts.join(" · "), errorDetails].filter(Boolean).join("\n"), validCount ? "success" : "error");
    elements["confirm-import-button"].disabled = importCount === 0;
  } catch (error) {
    if (requestNumber !== previewRequest) return;
    elements["preview-wrap"].hidden = true;
    elements["preview-body"].replaceChildren();
    setImportMessage(error.message || "Could not preview these columns.", "error");
    elements["confirm-import-button"].disabled = true;
  }
}

function csvCell(value) {
  let text = String(value);
  if (/^[\s]*[=+\-@]/.test(text)) text = `'${text}`;
  return `"${text.replace(/"/g, '""')}"`;
}

function exportCsv() {
  const rows = [["Date", "Description", "Type", "Amount (INR)", "Source"]];
  for (const transaction of transactions) {
    const paise = transaction.amount_paise;
    rows.push([
      transaction.date,
      transaction.description,
      transaction.type,
      `${Math.floor(paise / 100)}.${String(paise % 100).padStart(2, "0")}`,
      transaction.source === "csv" ? "CSV import" : "Manual",
    ]);
  }
  const contents = rows.map((row) => row.map(csvCell).join(",")).join("\r\n");
  const url = URL.createObjectURL(new Blob([`\uFEFF${contents}`], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = "rupee-ledger.csv";
  link.click();
  URL.revokeObjectURL(url);
}

document.getElementById("show-entry-button").addEventListener("click", openEntryForm);
document.getElementById("empty-add-button").addEventListener("click", openEntryForm);
document.getElementById("cancel-entry-button").addEventListener("click", () => {
  elements["entry-form"].hidden = true;
});

elements["entry-form"].addEventListener("submit", async (event) => {
  event.preventDefault();
  hideNotice();
  try {
    await apiRequest("/api/transactions", {
      date: elements["entry-date"].value,
      description: elements["entry-description"].value,
      amount: elements["entry-amount"].value,
      type: elements["entry-type"].value,
    });
    elements["entry-form"].reset();
    elements["entry-form"].hidden = true;
    await refreshLedger();
    showNotice("Transaction saved in the local ledger.");
  } catch (error) {
    showNotice(error.message || "Could not save this transaction.", "error");
  }
});

elements["search-input"].addEventListener("input", render);
elements["type-filter"].addEventListener("change", render);
document.getElementById("export-button").addEventListener("click", exportCsv);
document.getElementById("choose-file-button").addEventListener("click", () => {
  elements["statement-file"].click();
});
document.getElementById("cancel-import-button").addEventListener("click", () => {
  previewRequest += 1;
  elements["import-panel"].hidden = true;
  elements["statement-file"].value = "";
  stagedImport = null;
});
elements["skip-duplicates"].addEventListener("change", () => {
  if (!stagedImport?.review) return;
  renderImportPreview();
});

for (const definition of columnDefinitions) {
  elements[definition.id].addEventListener("change", renderImportPreview);
}

elements["statement-file"].addEventListener("change", async (event) => {
  const file = event.target.files?.[0];
  if (!file) return;
  previewRequest += 1;
  stagedImport = null;
  elements["import-panel"].hidden = false;
  elements["import-filename"].textContent = file.name;
  elements["preview-wrap"].hidden = true;
  elements["confirm-import-button"].disabled = true;
  setImportMessage("Reading this file locally…");

  try {
    if (file.size > 5 * 1024 * 1024) throw new Error("Choose a CSV file smaller than 5 MB.");
    const csvText = await file.text();
    const response = await apiRequest("/api/import/headers", { csv_text: csvText });
    stagedImport = { csvText, review: null };
    addColumnOptions(response.headers);
    await renderImportPreview();
    elements["import-panel"].scrollIntoView({ behavior: "smooth", block: "nearest" });
  } catch (error) {
    stagedImport = null;
    setImportMessage(error.message || "Could not read the selected file.", "error");
  }
});

elements["confirm-import-button"].addEventListener("click", async () => {
  const candidates = stagedImport?.review?.transactions;
  if (!candidates?.length) return;
  elements["confirm-import-button"].disabled = true;
  try {
    const result = await apiRequest("/api/import/commit", {
      transactions: candidates,
      skip_duplicates: elements["skip-duplicates"].checked,
    });
    await refreshLedger();
    elements["import-panel"].hidden = true;
    elements["statement-file"].value = "";
    stagedImport = null;
    showNotice(
      `${result.imported_count} transaction${result.imported_count === 1 ? "" : "s"} imported`
      + (result.skipped_count ? `; ${result.skipped_count} exact match${result.skipped_count === 1 ? "" : "es"} skipped.` : "."),
    );
  } catch (error) {
    setImportMessage(error.message || "Could not save the import.", "error");
    elements["confirm-import-button"].disabled = false;
  }
});

Promise.resolve()
  .then(refreshLedger)
  .catch((error) => {
    showNotice(
      `${error.message || "The local ledger could not be reached."} Start the app with python server.py.`,
      "error",
    );
  });

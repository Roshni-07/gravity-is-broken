# Rupee Ledger

A local-first personal payment-history ledger. This first increment focuses on reliable INR transaction records and honest data-source status rather than simulated bank or UPI connections.

## Run locally

Requires Python 3.10 or later; there are no third-party packages.

```powershell
python server.py
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000). Stop the app with Ctrl+C.

Run the focused tests with:

```powershell
python -m unittest discover -s tests -v
```

## What works

- Add debit and credit transactions with INR amounts stored as integer paise.
- Import a CSV statement by selecting its date, description, amount, and optional direction columns. Review valid rows and errors, then explicitly confirm before saving.
- Optionally skip exact matches. Because statement exports do not share a universal transaction identifier, these are only possible duplicates; the preview calls them out and allows them to be included.
- Search and filter records, view exact income/expense/net recorded totals, and export a CSV copy.
- Store data in a local SQLite database at `.local/finance.sqlite3`. The browser communicates only with the loopback server on this device; no credentials or financial records leave the device.

The app starts with an empty ledger; it does not create sample transactions. The totals describe only records entered here, not a verified account balance. The local database is not encrypted, synced, or backed up automatically. Export a backup and protect the device that holds it.

## Payment-source status

**UPI is not connected.** There is no provider integration, bank authorization flow, webhook, or automatic message parsing in this repository. CSV import is a user-initiated file import, not a bank connection; imported entries are not independently verified. Statement export formats vary, so users must choose columns and check the preview.

## Development checklist

- [x] Establish a small, dependency-free local web app and exact INR paise model.
- [x] Build manual transaction entry and a preview-first statement CSV import flow.
- [x] Store records in local SQLite; show explicit unsupported-UPI and unverified-import status.
- [x] Add focused tests for money parsing, CSV quoting, date normalization, statement mapping, duplicate handling, and totals.
- [ ] Run the local app in a browser and validate CSV column mappings against a redacted statement export.
- [ ] Choose a supported statement format/provider and validate it with redacted sample files.
- [ ] Add provider-specific identifiers and matching rules before attempting synchronization or stronger duplicate resolution.
- [ ] Select an authorized bank/UPI provider and design the required consent, backend security, and compliance flow before implementing a real integration.

The next step is to run the app and verify its import mapping against a redacted CSV from the statement source you actually use. Real bank/UPI access requires selecting a provider with documented API access and completing its authorization and security setup; none is configured here.

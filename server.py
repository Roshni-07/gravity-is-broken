"""Loopback-only HTTP server for the Rupee Ledger browser app."""

import argparse
import json
import logging
import sqlite3
from http.server import HTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlsplit

from ledger import (
    LedgerStore,
    map_statement_rows,
    parse_csv,
    parse_rupees_to_paise,
)

ROOT = Path(__file__).resolve().parent
STATIC_DIR = ROOT / "static"
DATABASE_PATH = ROOT / ".local" / "finance.sqlite3"
MAX_REQUEST_BYTES = 12 * 1024 * 1024
LOGGER = logging.getLogger("rupee-ledger")


class LedgerRequestHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(STATIC_DIR), **kwargs)

    def end_headers(self):
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cache-Control", "no-store")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; style-src 'self'; script-src 'self'; "
            "connect-src 'self'; img-src 'self' data:; object-src 'none'; "
            "base-uri 'none'; frame-ancestors 'none'",
        )
        super().end_headers()

    def _json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _read_json(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as error:
            raise ValueError("Invalid request length.") from error
        if length <= 0 or length > MAX_REQUEST_BYTES:
            raise ValueError("Request is empty or larger than the allowed limit.")
        try:
            payload = json.loads(self.rfile.read(length))
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            raise ValueError("Request body must be valid JSON.") from error
        if not isinstance(payload, dict):
            raise ValueError("Request body must be a JSON object.")
        return payload

    def do_GET(self):
        if self.headers.get("Host") != f"127.0.0.1:{self.server.server_port}":
            self._json(421, {"error": "Use the local 127.0.0.1 address shown when the app starts."})
            return
        path = urlsplit(self.path).path
        if path == "/api/transactions":
            self._json(200, {"transactions": self.server.store.list_transactions()})
        elif path == "/api/summary":
            self._json(200, self.server.store.summary())
        else:
            super().do_GET()

    def do_POST(self):
        path = urlsplit(self.path).path
        if path not in {
            "/api/transactions",
            "/api/import/headers",
            "/api/import/preview",
            "/api/import/commit",
        }:
            self._json(404, {"error": "Endpoint not found."})
            return

        if self.headers.get("Host") != f"127.0.0.1:{self.server.server_port}":
            self._json(421, {"error": "Use the local 127.0.0.1 address shown when the app starts."})
            return
        if self.headers.get("Origin") != self.server.allowed_origin:
            self._json(403, {"error": "Request origin is not allowed."})
            return
        if self.headers.get("X-Requested-With") != "RupeeLedger":
            self._json(403, {"error": "Request verification header is required."})
            return
        if self.headers.get_content_type() != "application/json":
            self._json(415, {"error": "Send request data as JSON."})
            return

        try:
            payload = self._read_json()
            if path == "/api/transactions":
                transaction = {
                    "date": payload.get("date"),
                    "description": payload.get("description"),
                    "amount_paise": parse_rupees_to_paise(payload.get("amount")),
                    "type": payload.get("type"),
                }
                if transaction["amount_paise"] <= 0:
                    raise ValueError("Enter an amount greater than zero.")
                saved = self.server.store.add_manual(transaction)
                self._json(201, {"transaction": saved})
            elif path == "/api/import/headers":
                rows = parse_csv(payload.get("csv_text"))
                if len(rows) < 2:
                    raise ValueError("The CSV needs a header row and at least one transaction row.")
                self._json(200, {"headers": rows[0], "row_count": len(rows) - 1})
            elif path == "/api/import/preview":
                rows = parse_csv(payload.get("csv_text"))
                result = map_statement_rows(rows, payload.get("columns"))
                self._json(200, {
                    **result,
                    "duplicate_count": self.server.store.count_duplicates(result["transactions"]),
                    "row_count": len(rows) - 1,
                })
            else:
                imported = self.server.store.import_transactions(
                    payload.get("transactions"),
                    payload.get("skip_duplicates"),
                )
                self._json(200, {
                    "imported_count": len(imported["imported"]),
                    "skipped_count": imported["skipped"],
                })
        except ValueError as error:
            self._json(400, {"error": str(error)})
        except (sqlite3.Error, OSError):
            LOGGER.exception("Could not complete local ledger request")
            self._json(500, {"error": "The local ledger could not complete this request."})


def create_server(store, port):
    server = HTTPServer(("127.0.0.1", port), LedgerRequestHandler)
    server.store = store
    server.allowed_origin = f"http://127.0.0.1:{server.server_port}"
    return server


def main():
    parser = argparse.ArgumentParser(description="Run the local Rupee Ledger app.")
    parser.add_argument("--port", type=int, default=8000, help="Local port (default: 8000)")
    args = parser.parse_args()
    if not 1 <= args.port <= 65535:
        parser.error("--port must be between 1 and 65535")

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    store = LedgerStore(DATABASE_PATH)
    server = create_server(store, args.port)
    print(f"Rupee Ledger is available at http://127.0.0.1:{server.server_port}")
    print(f"Local database: {DATABASE_PATH}")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Rupee Ledger.")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

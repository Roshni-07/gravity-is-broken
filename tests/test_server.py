import json
import tempfile
import threading
import unittest
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from ledger import LedgerStore
from server import create_server


class LocalServerTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        store = LedgerStore(Path(self.directory.name) / "ledger.sqlite3")
        self.server = create_server(store, 0)
        self.base_url = f"http://127.0.0.1:{self.server.server_port}"
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.directory.cleanup()

    def get(self, path):
        with urlopen(self.base_url + path, timeout=2) as response:
            return response.status, response.headers, json.loads(response.read())

    def post(self, path, payload, origin=None):
        request = Request(
            self.base_url + path,
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "X-Requested-With": "RupeeLedger",
                "Origin": origin or self.base_url,
            },
            method="POST",
        )
        return urlopen(request, timeout=2)

    def test_static_app_and_empty_ledger_are_served_with_security_headers(self):
        with urlopen(self.base_url + "/", timeout=2) as response:
            html = response.read().decode("utf-8")
            self.assertEqual(response.status, 200)
            self.assertIn("UPI not connected", html)
            self.assertIn("Content-Security-Policy", response.headers)

        status, _, transactions = self.get("/api/transactions")
        self.assertEqual((status, transactions), (200, {"transactions": []}))
        _, _, summary = self.get("/api/summary")
        self.assertEqual(summary, {
            "income_paise": "0",
            "expense_paise": "0",
            "net_paise": "0",
        })

    def test_manual_entry_and_csv_preview_then_confirmed_import(self):
        with self.post("/api/transactions", {
            "date": "2025-02-01",
            "description": "UPI grocery",
            "amount": "125.50",
            "type": "debit",
        }) as response:
            self.assertEqual(response.status, 201)

        csv_text = (
            "Date,Narration,Amount,Dr/Cr\n"
            "01/02/2025,UPI grocery,125.50,DR\n"
            "02/02/2025,Refund,5.25,CR\n"
            "bad-date,Invalid row,2.00,DR\n"
        )
        with self.post("/api/import/headers", {"csv_text": csv_text}) as response:
            self.assertEqual(json.loads(response.read())["headers"], ["Date", "Narration", "Amount", "Dr/Cr"])

        with self.post("/api/import/preview", {
            "csv_text": csv_text,
            "columns": {"date": 0, "description": 1, "amount": 2, "type": 3},
        }) as response:
            preview = json.loads(response.read())
        self.assertEqual((len(preview["transactions"]), len(preview["errors"])), (2, 1))
        self.assertEqual(preview["duplicate_count"], 1)

        with self.post("/api/import/commit", {
            "transactions": preview["transactions"],
            "skip_duplicates": True,
        }) as response:
            self.assertEqual(json.loads(response.read()), {
                "imported_count": 1,
                "skipped_count": 1,
            })

        _, _, summary = self.get("/api/summary")
        self.assertEqual(summary["income_paise"], "525")
        self.assertEqual(summary["expense_paise"], "12550")

    def test_mutations_reject_untrusted_origins(self):
        with self.assertRaises(HTTPError) as response:
            self.post("/api/transactions", {
                "date": "2025-02-01",
                "description": "Should not save",
                "amount": "1.00",
                "type": "debit",
            }, origin="http://untrusted.example")
        self.assertEqual(response.exception.code, 403)
        self.assertEqual(self.server.store.list_transactions(), [])

    def test_api_rejects_an_unexpected_host_header(self):
        request = Request(
            self.base_url + "/api/transactions",
            headers={"Host": f"untrusted.example:{self.server.server_port}"},
        )
        with self.assertRaises(HTTPError) as response:
            urlopen(request, timeout=2)
        self.assertEqual(response.exception.code, 421)


if __name__ == "__main__":
    unittest.main()

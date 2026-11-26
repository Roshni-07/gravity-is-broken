import tempfile
import unittest
from pathlib import Path

from ledger import (
    LedgerStore,
    format_paise,
    map_statement_rows,
    parse_csv,
    parse_rupees_to_paise,
    parse_statement_date,
    transaction_fingerprint,
)


class MoneyTests(unittest.TestCase):
    def test_exact_paise_parsing_and_inr_grouping(self):
        self.assertEqual(parse_rupees_to_paise("₹1,23,456.78"), 12_345_678)
        self.assertEqual(parse_rupees_to_paise("INR 0.5"), 50)
        self.assertEqual(parse_rupees_to_paise("-12.34"), -1_234)
        self.assertEqual(format_paise(12_345_678), "₹1,23,456.78")
        self.assertEqual(format_paise(-1), "−₹0.01")

    def test_ambiguous_or_overprecision_amounts_are_rejected(self):
        for amount in ("1,23.45", "10.999", "", "1e3"):
            with self.subTest(amount=amount):
                with self.assertRaises(ValueError):
                    parse_rupees_to_paise(amount)


class StatementTests(unittest.TestCase):
    def test_csv_quotes_bom_and_embedded_newlines(self):
        rows = parse_csv(
            '\ufeffDate,Details,Amount\r\n'
            '01/02/2025,"Cafe, ""South""\nbranch",125.50\r\n'
        )
        self.assertEqual(rows, [
            ["Date", "Details", "Amount"],
            ["01/02/2025", 'Cafe, "South"\nbranch', "125.50"],
        ])

    def test_maps_indian_dates_and_reports_bad_rows(self):
        result = map_statement_rows(
            [
                ["Txn Date", "Narration", "Amount", "Dr/Cr"],
                ["01/02/2025", "UPI grocery", "1,250.00", "DR"],
                ["2025-02-02", "Refund", "80.50", "CR"],
                ["31/02/2025", "Bad date", "2.00", "DR"],
                ["2025-02-03", "Signed debit", "-25.25", ""],
            ],
            {"date": 0, "description": 1, "amount": 2, "type": 3},
        )
        self.assertEqual(
            [
                (row["date"], row["amount_paise"], row["type"])
                for row in result["transactions"]
            ],
            [
                ("2025-02-01", 125_000, "debit"),
                ("2025-02-02", 8_050, "credit"),
                ("2025-02-03", 2_525, "debit"),
            ],
        )
        self.assertEqual(result["errors"], [
            {"line": 4, "message": "That date does not exist or is not supported."}
        ])

    def test_date_normalization_rejects_impossible_calendar_values(self):
        self.assertEqual(parse_statement_date("03-02-2025"), "2025-02-03")
        with self.assertRaises(ValueError):
            parse_statement_date("2025-02-30")


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.store = LedgerStore(Path(self.directory.name) / "ledger.sqlite3")

    def tearDown(self):
        self.directory.cleanup()

    def test_manual_records_and_totals_use_integer_paise(self):
        self.store.add_manual({
            "date": "2025-01-01",
            "description": "Rent",
            "amount_paise": 9_007_199_254_740_000,
            "type": "debit",
        })
        self.store.add_manual({
            "date": "2025-01-02",
            "description": "Salary",
            "amount_paise": 9_007_199_254_740_000,
            "type": "credit",
        })
        self.assertEqual(self.store.summary(), {
            "income_paise": "9007199254740000",
            "expense_paise": "9007199254740000",
            "net_paise": "0",
        })

    def test_import_skip_duplicates_is_explicit_and_normalized(self):
        candidate = {
            "date": "2025-02-01",
            "description": "Coffee",
            "amount_paise": 4500,
            "type": "debit",
        }
        self.store.add_manual(candidate)
        self.assertEqual(self.store.count_duplicates([candidate]), 1)

        skipped = self.store.import_transactions([candidate, candidate], True)
        self.assertEqual((len(skipped["imported"]), skipped["skipped"]), (0, 2))
        included = self.store.import_transactions([candidate], False)
        self.assertEqual((len(included["imported"]), included["skipped"]), (1, 0))
        self.assertEqual(len(self.store.list_transactions()), 2)

    def test_fingerprint_ignores_description_case_and_surrounding_spaces(self):
        first = {
            "date": "2025-02-01",
            "description": "  UPI Coffee ",
            "amount_paise": 4500,
            "type": "debit",
        }
        second = {**first, "description": "upi coffee"}
        self.assertEqual(transaction_fingerprint(first), transaction_fingerprint(second))


if __name__ == "__main__":
    unittest.main()

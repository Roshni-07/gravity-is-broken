"""Local-first payment ledger primitives and SQLite persistence."""

import csv
import io
import re
import sqlite3
import uuid
from contextlib import contextmanager
from datetime import date, datetime
from pathlib import Path

MAX_SAFE_PAISE = 9_007_199_254_740_991
MAX_DESCRIPTION_LENGTH = 160
_RUPEE_AMOUNT = re.compile(
    r"^([+-]?)(\d+|\d{1,3}(?:,\d{3})+|\d{1,2}(?:,\d{2})*,\d{3})(?:\.(\d{1,2}))?$"
)


def parse_rupees_to_paise(value):
    """Parse an INR amount without using floating-point arithmetic."""
    if not isinstance(value, str):
        raise ValueError("Enter the amount as text.")
    value = value.strip()
    value = re.sub(r"^(?:₹|INR)\s*", "", value, flags=re.IGNORECASE)
    match = _RUPEE_AMOUNT.fullmatch(value)
    if not match:
        raise ValueError("Use a rupee amount with up to two decimal places.")

    rupees = int(match.group(2).replace(",", ""))
    paise = rupees * 100 + int((match.group(3) or "").ljust(2, "0") or "0")
    if paise > MAX_SAFE_PAISE:
        raise ValueError("That amount is too large to store safely.")
    return -paise if match.group(1) == "-" else paise


def format_paise(paise):
    if not isinstance(paise, int) or isinstance(paise, bool):
        raise TypeError("Paise must be an integer.")
    absolute = abs(paise)
    rupees, fraction = divmod(absolute, 100)
    digits = str(rupees)
    groups = []
    if len(digits) > 3:
        groups.append(digits[-3:])
        digits = digits[:-3]
        while digits:
            groups.append(digits[-2:])
            digits = digits[:-2]
        whole = ",".join(reversed(groups))
    else:
        whole = digits
    sign = "−" if paise < 0 else ""
    return f"{sign}₹{whole}.{fraction:02d}"


def parse_statement_date(value):
    if not isinstance(value, str):
        raise ValueError("Use YYYY-MM-DD or DD/MM/YYYY for dates.")
    text = value.strip()
    formats = ("%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y")
    for date_format in formats:
        try:
            parsed = date.fromisoformat(text) if date_format == "%Y-%m-%d" else (
                datetime.strptime(text, date_format).date()
            )
            return parsed.isoformat()
        except ValueError:
            continue
    raise ValueError("That date does not exist or is not supported.")


def parse_csv(text):
    if not isinstance(text, str) or not text:
        raise ValueError("The selected CSV file is empty.")
    if len(text.encode("utf-8")) > 5 * 1024 * 1024:
        raise ValueError("Choose a CSV file smaller than 5 MB.")

    try:
        rows = list(csv.reader(io.StringIO(text.lstrip("\ufeff"), newline=""), strict=True))
    except csv.Error as error:
        raise ValueError(f"Could not parse CSV: {error}") from error
    rows = [row for row in rows if any(cell.strip() for cell in row)]
    if not rows:
        raise ValueError("The selected CSV file has no rows.")
    return rows


def _parse_direction(value, signed_amount):
    direction = value.strip().casefold()
    if not direction:
        return "debit" if signed_amount < 0 else "credit"
    if direction in {"debit", "dr", "withdrawal", "paid", "sent", "out"}:
        return "debit"
    if direction in {"credit", "cr", "deposit", "received", "in"}:
        return "credit"
    raise ValueError("Type must be debit/DR or credit/CR, or leave it blank.")


def map_statement_rows(rows, columns):
    if not isinstance(rows, list) or len(rows) < 2:
        raise ValueError("The CSV needs a header row and at least one transaction row.")
    if not isinstance(columns, dict):
        raise ValueError("Choose which CSV columns contain the transaction details.")

    header = rows[0]
    required = ("date", "description", "amount")
    indexes = {}
    for name in required:
        index = columns.get(name)
        if not isinstance(index, int) or isinstance(index, bool) or not 0 <= index < len(header):
            raise ValueError(f"Choose a valid {name} column.")
        indexes[name] = index
    if len(set(indexes.values())) != len(required):
        raise ValueError("Date, description, and amount must use different columns.")

    type_index = columns.get("type")
    if type_index not in (None, ""):
        if not isinstance(type_index, int) or isinstance(type_index, bool) or not 0 <= type_index < len(header):
            raise ValueError("Choose a valid type column or leave it unmapped.")
        if type_index in indexes.values():
            raise ValueError("Type must use a different column from date, description, and amount.")
    else:
        type_index = None

    transactions = []
    errors = []
    for line_number, row in enumerate(rows[1:], start=2):
        if len(row) != len(header):
            errors.append({
                "line": line_number,
                "message": "This row has a different number of columns than the header.",
            })
            continue
        try:
            description = row[indexes["description"]].strip()
            if not description:
                raise ValueError("Description cannot be blank.")
            if len(description) > MAX_DESCRIPTION_LENGTH:
                raise ValueError("Description is longer than 160 characters.")

            signed_amount = parse_rupees_to_paise(row[indexes["amount"]])
            if signed_amount == 0:
                raise ValueError("Amount must be greater than zero.")
            direction = _parse_direction(
                row[type_index] if type_index is not None else "",
                signed_amount,
            )
            transactions.append({
                "date": parse_statement_date(row[indexes["date"]]),
                "description": description,
                "amount_paise": abs(signed_amount),
                "type": direction,
                "source": "csv",
            })
        except ValueError as error:
            errors.append({"line": line_number, "message": str(error)})
    return {"transactions": transactions, "errors": errors}


def transaction_fingerprint(transaction):
    return (
        transaction["date"],
        transaction["type"],
        transaction["amount_paise"],
        transaction["description"].strip().casefold(),
    )


def validate_transaction(transaction, expected_source):
    if not isinstance(transaction, dict):
        raise ValueError("Transaction details must be an object.")
    description = transaction.get("description")
    if not isinstance(description, str) or not description.strip():
        raise ValueError("Description cannot be blank.")
    description = description.strip()
    if len(description) > MAX_DESCRIPTION_LENGTH:
        raise ValueError("Description is longer than 160 characters.")

    amount_paise = transaction.get("amount_paise")
    if (
        not isinstance(amount_paise, int)
        or isinstance(amount_paise, bool)
        or not 0 < amount_paise <= MAX_SAFE_PAISE
    ):
        raise ValueError("Amount must be a positive, safely representable number of paise.")
    direction = transaction.get("type")
    if not isinstance(direction, str) or direction not in {"debit", "credit"}:
        raise ValueError("Choose money in or money out.")

    return {
        "date": parse_statement_date(transaction.get("date")),
        "description": description,
        "amount_paise": amount_paise,
        "type": direction,
        "source": expected_source,
    }


class LedgerStore:
    def __init__(self, path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self._connection() as connection:
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS transactions (
                    id TEXT PRIMARY KEY,
                    date TEXT NOT NULL,
                    description TEXT NOT NULL,
                    amount_paise INTEGER NOT NULL CHECK (amount_paise > 0),
                    type TEXT NOT NULL CHECK (type IN ('debit', 'credit')),
                    source TEXT NOT NULL CHECK (source IN ('manual', 'csv')),
                    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
                )
                """
            )
            connection.execute(
                "CREATE INDEX IF NOT EXISTS transactions_date_idx ON transactions(date DESC, created_at DESC)"
            )

    def _connect(self):
        connection = sqlite3.connect(self.path, timeout=5)
        connection.row_factory = sqlite3.Row
        return connection

    @contextmanager
    def _connection(self):
        connection = self._connect()
        try:
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()

    @staticmethod
    def _record(row):
        return {
            "id": row["id"],
            "date": row["date"],
            "description": row["description"],
            "amount_paise": row["amount_paise"],
            "type": row["type"],
            "source": row["source"],
        }

    def list_transactions(self):
        with self._connection() as connection:
            rows = connection.execute(
                """
                SELECT id, date, description, amount_paise, type, source
                FROM transactions
                ORDER BY date DESC, created_at DESC, id DESC
                """
            ).fetchall()
        return [self._record(row) for row in rows]

    def summary(self):
        income = 0
        expenses = 0
        for transaction in self.list_transactions():
            if transaction["type"] == "credit":
                income += transaction["amount_paise"]
            else:
                expenses += transaction["amount_paise"]
        return {
            "income_paise": str(income),
            "expense_paise": str(expenses),
            "net_paise": str(income - expenses),
        }

    def add_manual(self, transaction):
        record = validate_transaction(transaction, "manual")
        record["id"] = str(uuid.uuid4())
        with self._connection() as connection:
            connection.execute(
                """
                INSERT INTO transactions (id, date, description, amount_paise, type, source)
                VALUES (:id, :date, :description, :amount_paise, :type, :source)
                """,
                record,
            )
        return record

    def count_duplicates(self, candidates):
        known = {
            transaction_fingerprint(transaction)
            for transaction in self.list_transactions()
        }
        duplicates = 0
        for candidate in candidates:
            fingerprint = transaction_fingerprint(candidate)
            if fingerprint in known:
                duplicates += 1
            known.add(fingerprint)
        return duplicates

    def import_transactions(self, candidates, skip_duplicates):
        if not isinstance(candidates, list):
            raise ValueError("Imported transactions must be a list.")
        if not isinstance(skip_duplicates, bool):
            raise ValueError("Choose whether exact matches should be skipped.")
        validated = [validate_transaction(candidate, "csv") for candidate in candidates]

        with self._connection() as connection:
            rows = connection.execute(
                "SELECT date, description, amount_paise, type FROM transactions"
            ).fetchall()
            known = {
                transaction_fingerprint({
                    "date": row["date"],
                    "description": row["description"],
                    "amount_paise": row["amount_paise"],
                    "type": row["type"],
                })
                for row in rows
            }
            inserted = []
            skipped = 0
            for transaction in validated:
                fingerprint = transaction_fingerprint(transaction)
                if skip_duplicates and fingerprint in known:
                    skipped += 1
                    continue
                record = {**transaction, "id": str(uuid.uuid4())}
                connection.execute(
                    """
                    INSERT INTO transactions (id, date, description, amount_paise, type, source)
                    VALUES (:id, :date, :description, :amount_paise, :type, :source)
                    """,
                    record,
                )
                inserted.append(record)
                known.add(fingerprint)
        return {"imported": inserted, "skipped": skipped}

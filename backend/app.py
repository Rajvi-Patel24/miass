from datetime import datetime, timezone
import hashlib
import sqlite3
from pathlib import Path

from flask import Flask, jsonify, request
from flask_cors import CORS

from simulator import SimulatorError, VerilogSimulator

BASE_DIR = Path(__file__).resolve().parent
DATABASE = BASE_DIR / "data" / "transactions.db"
app = Flask(__name__)
CORS(app)
simulator = VerilogSimulator(BASE_DIR)


def get_db():
    DATABASE.parent.mkdir(exist_ok=True)
    connection = sqlite3.connect(DATABASE)
    connection.row_factory = sqlite3.Row
    return connection


def init_db():
    with get_db() as connection:
        columns = {row[1] for row in connection.execute("PRAGMA table_info(transactions)").fetchall()}
        if columns and "recipient_id" not in columns:
            connection.execute("ALTER TABLE transactions RENAME TO transactions_legacy")
        connection.execute("""CREATE TABLE IF NOT EXISTS transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            recipient_id TEXT NOT NULL,
            recipient_code INTEGER NOT NULL,
            amount INTEGER NOT NULL,
            event_time INTEGER NOT NULL,
            failed INTEGER NOT NULL,
            decision TEXT NOT NULL,
            decision_code INTEGER NOT NULL,
            reason_code INTEGER NOT NULL,
            reason TEXT NOT NULL
        )""")


def recipient_code(recipient_id):
    digest = hashlib.sha256(recipient_id.strip().lower().encode("utf-8")).digest()
    return int.from_bytes(digest[:2], "big") or 1


def validate_payload(payload):
    if not isinstance(payload, dict):
        raise ValueError("Request body must be a JSON object.")
    recipient_id = payload.get("recipient_id")
    if not isinstance(recipient_id, str) or not recipient_id.strip() or len(recipient_id.strip()) > 40:
        raise ValueError("Recipient ID must be 1 to 40 characters.")
    amount = payload.get("amount")
    if isinstance(amount, bool) or not isinstance(amount, int):
        raise ValueError("Amount must be an integer.")
    if amount < 1 or amount > 10000:
        raise ValueError("Amount must be between ₹1 and ₹10,000.")
    normalized_id = recipient_id.strip()
    return {"recipient_id": normalized_id, "recipient_code": recipient_code(normalized_id), "amount": amount}


def load_events():
    with get_db() as connection:
        rows = connection.execute("SELECT recipient_code, amount, event_time, failed FROM transactions ORDER BY id").fetchall()
    return [dict(row) for row in rows]


@app.get("/api/health")
def health():
    try:
        simulator.ensure_compiled()
        return jsonify({"backend": True, "simulator": True, "message": "Verilog simulator is connected and compiled."})
    except SimulatorError as error:
        return jsonify({"backend": True, "simulator": False, "message": str(error)})


@app.post("/api/analyze")
def analyze():
    try:
        transaction = validate_payload(request.get_json(silent=True))
        created_at = datetime.now(timezone.utc)
        events = load_events()
        events.append({**transaction, "event_time": int(created_at.timestamp()), "failed": False})
        result = simulator.analyze(events)
    except ValueError as error:
        return jsonify({"error": str(error)}), 400
    except SimulatorError as error:
        return jsonify({"error": str(error), "simulator": True}), 503

    with get_db() as connection:
        cursor = connection.execute(
            "INSERT INTO transactions (created_at, recipient_id, recipient_code, amount, event_time, failed, decision, decision_code, reason_code, reason) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (created_at.isoformat(), transaction["recipient_id"], transaction["recipient_code"], transaction["amount"], events[-1]["event_time"], 0, result["decision"], result["code"], result["reason_code"], result["reason"]),
        )
        transaction_id = cursor.lastrowid
    return jsonify({"id": transaction_id, "created_at": created_at.isoformat(), **transaction, **result})


@app.get("/api/transactions")
def transactions():
    with get_db() as connection:
        rows = connection.execute("SELECT id, created_at, recipient_id, amount, decision FROM transactions ORDER BY id DESC LIMIT 50").fetchall()
    return jsonify([dict(row) for row in rows])


init_db()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)

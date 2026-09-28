# FraudShield

FraudShield is a software-only Microprocessor and Interfacing assignment project. A user enters a simulated recipient ID and amount. Flask replays the stored transaction events into Icarus Verilog, and the Verilog engine detects patterns and returns ALLOW, VERIFY, or FLAG.

This is an educational simulator. It does not connect to UPI, banks, payment gateways, or real customer accounts. FLAG means flagged for review, not proven fraud.

## Architecture

React sends `{ recipient_id, amount }` to Flask. Flask validates the inputs and loads the ordered SQLite event history. The simulator writes that history plus the new event to a replay file and runs `iverilog`/`vvp`. `fraud_engine.v` resets, clocks through every event, checks its configured watchlist, tracks recipient repetitions, rapid attempts, and controlled failed-attempt sequences, then applies the final priority:

1. FLAG: watchlist match, rapid changing-recipient threshold, or repeated-failure threshold.
2. VERIFY: amount at least ₹5,000 or repeated-payment threshold.
3. ALLOW: no rule triggered.

Python stores the result returned by Verilog. It does not calculate a risk score or decision.

## Configured simulation rules

- Valid amount: ₹1 through ₹10,000.
- Verification amount threshold: ₹5,000.
- Repeated payment: 3 events for the same recipient within 300 simulated seconds.
- Rapid attempts: 3 quick events involving changing recipients within 30 simulated seconds.
- Repeated failures: 3 consecutive controlled failed events.
- Watchlist examples: `watchlist-13` and `watchlist-404`. Their numeric codes are compared inside Verilog.
- For demonstration, failed events are supplied by the Verilog scenario testbench; the simple user form does not claim to detect real bank failures.

## Windows setup

Install Python 3.11+, Node.js LTS, and Icarus Verilog. Ensure the Icarus `bin` directory is on PATH. Open a new PowerShell window and verify:

```powershell
python --version
node --version
iverilog -V
vvp -V
```

Install Flask:

```powershell
cd "C:\Users\HP\academics\5th sem\miass\FraudShield"
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r backend\requirements.txt
```

Compile and run the actual Verilog scenarios:

```powershell
cd backend
New-Item -ItemType Directory -Force build
iverilog -o build\scenario_testbench.vvp fraud_engine.v scenario_testbench.v
vvp build\scenario_testbench.vvp
```

Expected final line:

```text
SUMMARY|total=7|passed=7|failed=0
```

Start Flask in one terminal:

```powershell
cd "C:\Users\HP\academics\5th sem\miass\FraudShield\backend"
python app.py
```

Start React in another:

```powershell
cd "C:\Users\HP\academics\5th sem\miass\FraudShield\frontend"
npm install
npm run dev
```

Open the Vite URL, normally `http://localhost:5173`. If that port is busy, use the alternate URL printed by Vite.

## API

- `GET /api/health` reports Flask and Icarus availability.
- `POST /api/analyze` accepts `recipient_id` and integer `amount` and returns the actual Verilog decision and reason.
- `GET /api/transactions` returns compact newest-first history records.

Invalid recipient IDs, missing values, non-integer amounts, amounts below ₹1, and amounts above ₹10,000 return HTTP 400. Missing Icarus executables, compilation errors, malformed output, and timeouts return an error; no fake decision is stored.

## Troubleshooting

- `iverilog is not recognized`: install Icarus Verilog, add its `bin` folder to PATH, and open a new terminal.
- `ModuleNotFoundError: flask`: activate `.venv` and run `pip install -r backend\requirements.txt`.
- The frontend cannot reach Flask: start `python app.py` from the `backend` folder and check `http://127.0.0.1:5000/api/health`.
- If Flask debug reload reports a missing file during editing, stop the old process and start it again from the absolute backend path.

## Limitations

The rules are illustrative, the timing units are simulated integer seconds, and failure events are controlled test data. This is not a production fraud detector and does not establish that any user or recipient is fraudulent.

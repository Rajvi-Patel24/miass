import { useState } from 'react';
import { AlertTriangle, ArrowUpRight, ShieldCheck } from 'lucide-react';
import './App.css';

const API = 'http://127.0.0.1:5000/api';

function App() {
  const [recipientId, setRecipientId] = useState('');
  const [amount, setAmount] = useState('');
  const [result, setResult] = useState(null);
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function analyze(event) {
    event.preventDefault();
    setBusy(true);
    setError('');
    setResult(null);
    try {
      const response = await fetch(`${API}/analyze`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ recipient_id: recipientId, amount: Number(amount) }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Analysis failed.');
      setResult(data);
    } catch (caught) {
      setError(caught.message || 'Unable to reach the Verilog engine.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="page-shell">
      <header className="brand-row">
        <div className="brand-icon"><ShieldCheck size={22} /></div>
        <div><strong>FraudShield</strong><span>Digital payment security simulator</span></div>
      </header>

      <section className="hero">
        <p className="kicker">VERILOG DECISION ENGINE</p>
        <h1>Make the payment.<br /><em>Read the signal.</em></h1>
        <p className="intro">Enter a simulated recipient and amount. FraudShield replays the transaction history through Verilog and returns the engine's decision.</p>
      </section>

      <section className="workspace">
        <form className="transaction-form" onSubmit={analyze}>
          <label>Recipient ID
            <input value={recipientId} onChange={(event) => setRecipientId(event.target.value)} placeholder="e.g. merchant-042" maxLength="40" required />
          </label>
          <label>Transaction amount <span>₹ INR</span>
            <input type="number" value={amount} onChange={(event) => setAmount(event.target.value)} min="1" max="10000" step="1" placeholder="0" required />
          </label>
          <button type="submit" disabled={busy}>{busy ? 'Running Verilog...' : 'Analyze Transaction'} <ArrowUpRight size={17} /></button>
        </form>

        <section className={`result ${result ? result.decision.toLowerCase() : 'waiting'}`} aria-live="polite">
          <p className="kicker">ENGINE RESULT</p>
          {result ? <>
            <div className="decision-line"><span>{result.decision}</span><b>CODE {String(result.code).padStart(2, '0')}</b></div>
            <p className="reason">{result.reason}</p>
            <p className="transaction-label">{result.recipient_id} · ₹{result.amount.toLocaleString('en-IN')}</p>
            <small>FLAG means flagged for review in this educational simulation, not proven fraud.</small>
          </> : <p className="waiting-copy">Your Verilog decision will appear here.</p>}
        </section>
      </section>

      {error && <div className="error"><AlertTriangle size={17} />{error}</div>}
      <footer>History is stored locally for ordered Verilog event replay. No real payment service is connected.</footer>
    </main>
  );
}

export default App;

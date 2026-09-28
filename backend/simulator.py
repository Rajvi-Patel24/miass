import re
import subprocess
from pathlib import Path


DECISIONS = {0: "ALLOW", 1: "VERIFY", 2: "FLAG"}
REASONS = {
    0: "No stronger risk pattern was detected.",
    1: "The amount is at or above the ₹5,000 verification threshold.",
    2: "Repeated payments to this recipient reached the verification threshold.",
    3: "The recipient matches the simulated watchlist.",
    4: "Rapid transaction attempts reached the flag threshold.",
    5: "Repeated failed attempts reached the flag threshold.",
}


class SimulatorError(RuntimeError):
    pass


class VerilogSimulator:
    def __init__(self, base_dir: Path):
        self.base_dir = Path(base_dir)
        self.build_dir = self.base_dir / "build"
        self.engine_executable = self.build_dir / "fraud_engine.vvp"
        self.suite_executable = self.build_dir / "testbench.vvp"

    def _run(self, command: list[str]) -> str:
        try:
            completed = subprocess.run(
                command,
                cwd=self.base_dir,
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
        except FileNotFoundError as exc:
            raise SimulatorError("Icarus Verilog is unavailable. Install iverilog and vvp, then restart Flask.") from exc
        except subprocess.TimeoutExpired as exc:
            raise SimulatorError("The Verilog simulator timed out.") from exc
        if completed.returncode != 0:
            detail = (completed.stderr or completed.stdout).strip()
            raise SimulatorError(f"Verilog command failed: {detail}")
        return completed.stdout

    def compile(self) -> None:
        self.build_dir.mkdir(exist_ok=True)
        self._run(["iverilog", "-o", str(self.engine_executable), "fraud_engine.v", "runner.v"])

    def ensure_compiled(self) -> None:
        sources = [self.base_dir / name for name in ("fraud_engine.v", "runner.v")]
        if not self.engine_executable.exists() or any(source.stat().st_mtime > self.engine_executable.stat().st_mtime for source in sources):
            self.compile()

    def analyze(self, events: list[dict]) -> dict:
        self.ensure_compiled()
        replay_file = self.build_dir / "replay_input.txt"
        with replay_file.open("w", encoding="ascii") as stream:
            stream.write(f"{len(events)}\n")
            for event in events:
                stream.write(f"{event['recipient_code']} {event['amount']} {event['event_time']} {int(event['failed'])}\n")
        command = ["vvp", str(self.engine_executable), f"+input={replay_file.resolve()}"]
        output = self._run(command)
        match = re.search(r"DECISION_CODE=(\d+)\|REASON_CODE=(\d+)", output)
        if not match or int(match.group(1)) not in DECISIONS or int(match.group(2)) not in REASONS:
            raise SimulatorError("The simulator returned malformed decision output.")
        code = int(match.group(1))
        reason_code = int(match.group(2))
        return {"code": code, "decision": DECISIONS[code], "reason_code": reason_code, "reason": REASONS[reason_code], "raw_output": output.strip()}

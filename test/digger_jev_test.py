import contextlib
import importlib.util
import io
import json
import os
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "digger/scripts"
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location("digger_jev", SCRIPTS / "jev.py")
jev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jev)


class JevTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.topic = self.root / "topic"
        (self.topic / "sources").mkdir(parents=True)
        (self.topic / "sources/source.txt").write_text("Only adults improved.\nChildren did not improve.\n")
        self.extracts = {"question": "Who improved?", "claims": [
            {"claim": "Everyone improved", "quotes": [{"file": "source.txt", "line": 1, "text": "Only adults improved."}]}]}
        self.config = {"version": 1, "credentials": {"typesafe": {"method": "environment", "variable": "DIGGER_TYPESAFE_API_KEY"}},
                       "jev": {"enabled": True, "model": "jev-latest", "credential_ref": "typesafe",
                               "allowed_roots": [str(self.topic)], "max_request_bytes": 60000, "max_requests_per_topic": 2}}
        self.write_inputs()
        self.requests = []
        self.failure = False
        self.invalid = False
        test = self

        class Connection:
            def __init__(self, host, timeout):
                test.assertEqual(host, "api.typesafe.ai")

            def request(self, method, path, body, headers):
                test.assertEqual((method, path), ("POST", "/v1/systemone"))
                test.assertEqual(headers["Authorization"], "Bearer test-secret")
                test.requests.append(json.loads(body))

            def getresponse(self):
                return self

            @property
            def status(self):
                return 503 if test.failure else 200

            def read(self, limit):
                answers = {}
                for name, question in test.requests[-1]["questions"].items():
                    options = question["criteria"]
                    choice = "qualified" if "qualified" in options else "unknown" if "unknown" in options else "missing"
                    answers[name] = {"type": "choice", "choice": choice, "confidence": 0.9,
                                     "probabilities": {option: int(option == choice) for option in options}}
                if test.invalid:
                    answers = {}
                return json.dumps({"model": "jev-test", "answers": answers,
                                   "usage": {"input_tokens": 123, "output_tokens": 10}}).encode()

            def close(self):
                pass

        self.addCleanup(patch.stopall)
        patch.object(jev.http.client, "HTTPSConnection", Connection).start()
        patch.dict(os.environ, {"DIGGER_TYPESAFE_API_KEY": "test-secret"}).start()

    def write_inputs(self):
        (self.topic / "extracts.json").write_text(json.dumps(self.extracts))
        (self.root / "config.json").write_text(json.dumps(self.config))

    def run_jev(self, mode="citations", extra=()):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = jev.main([mode, str(self.topic), "--config", str(self.root / "config.json"), *extra])
        return code, json.loads(output.getvalue())

    def test_citations_keep_context_and_original_and_separate_judgment(self):
        before = (self.topic / "extracts.json").read_bytes()
        code, result = self.run_jev()
        self.assertEqual(code, 0)
        record = json.loads(Path(result["result"]).read_text())
        self.assertEqual(record["answers"]["item_0"]["choice"], "qualified")
        self.assertTrue(record["requires_review"])
        self.assertIn("Children did not improve", self.requests[0]["state"]["items"][0]["context"])
        self.assertEqual((self.topic / "extracts.json").read_bytes(), before)
        self.assertNotIn("test-secret", Path(result["result"]).read_text())

    def test_gaps_batch_sufficiency_and_freshness_without_local_paths(self):
        knowledge = {"question": "Who improved?", "as_of": "2026-10-21", "freshness_requirement": "2026 results",
                     "claims": [{"claim": "Everyone improved", "evidence": [{"file": "sources/source.txt", "line": 1, "end": 2}]}]}
        (self.topic / "knowledge.json").write_text(json.dumps(knowledge))
        self.run_jev("gaps")
        self.assertEqual(set(self.requests[0]["questions"]), {"item_0", "freshness_0"})
        self.assertNotIn(str(self.topic), json.dumps(self.requests))

    def test_preview_disabled_and_invalid_quotes_never_send(self):
        self.run_jev(extra=["--preview"])
        self.assertFalse((self.topic / "jev").exists())
        self.extracts["claims"][0]["quotes"][0]["text"] = "Invented text"
        self.write_inputs()
        with self.assertRaisesRegex(jev.CheckError, "Quote mismatch"):
            self.run_jev()
        self.config["jev"]["enabled"] = False
        self.write_inputs()
        self.assertEqual(self.run_jev()[1]["status"], "disabled")
        self.assertEqual(self.requests, [])

    def test_outside_symlink_and_size_limits_prevent_submission(self):
        outside = self.root / "private.txt"
        outside.write_text("Only adults improved.")
        source = self.topic / "sources/source.txt"
        source.unlink()
        source.symlink_to(outside)
        with self.assertRaisesRegex(jev.CheckError, "outside allowed_roots"):
            self.run_jev()
        source.unlink()
        source.write_text("Only adults improved.")
        self.config["jev"]["max_request_bytes"] = 10
        self.write_inputs()
        with self.assertRaisesRegex(jev.CheckError, "Payload exceeds"):
            self.run_jev()
        self.assertEqual(self.requests, [])

    def test_api_failures_record_unverified_and_consume_budget_without_retries(self):
        self.failure = True
        code, result = self.run_jev()
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(Path(result["result"]).read_text())["status"], "unverified")
        self.failure, self.invalid = False, True
        self.assertEqual(self.run_jev()[0], 1)
        with self.assertRaisesRegex(jev.CheckError, "budget exhausted"):
            self.run_jev()
        self.assertEqual(len(self.requests), 2)

    def test_missing_key_does_not_consume_budget(self):
        with patch.dict(os.environ, {"DIGGER_TYPESAFE_API_KEY": ""}):
            with self.assertRaisesRegex(jev.CheckError, "credential is missing"):
                self.run_jev()
        self.assertFalse((self.topic / "jev").exists())

    def test_envchain_receives_only_reference_and_reexecutes_current_python(self):
        self.config["credentials"]["typesafe"] = {"method": "envchain", "namespace": "digger", "variable": "DIGGER_TYPESAFE_API_KEY"}
        self.write_inputs()
        helper = self.root / "envchain"
        capture = self.root / "args.json"
        helper.write_text(f"#!{sys.executable}\nimport json, sys\nfrom pathlib import Path\n"
                          f"Path({str(capture)!r}).write_text(json.dumps(sys.argv[1:]))\n"
                          "print(json.dumps({'status': 'judged', 'result': 'fixture'}))\n")
        helper.chmod(0o700)
        with patch.dict(os.environ, {"PATH": str(self.root) + os.pathsep + os.environ["PATH"]}):
            result = subprocess.run([sys.executable, str(SCRIPTS / "jev.py"), "citations", str(self.topic),
                                     "--config", str(self.root / "config.json")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads(capture.read_text())
        self.assertEqual(args[:2], ["digger", sys.executable])
        self.assertEqual(args[-1], "--credential-loaded")
        self.assertNotIn("test-secret", result.stdout + result.stderr + capture.read_text())
        self.assertEqual(self.requests, [])

    def test_cli_invalid_input_reports_failure_without_traceback_or_secrets(self):
        self.extracts["claims"][0]["quotes"][0]["line"] = "test-secret"
        self.write_inputs()
        result = subprocess.run([sys.executable, str(SCRIPTS / "jev.py"), "citations", str(self.topic),
                                 "--config", str(self.root / "config.json")], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertNotIn("test-secret", result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stderr)


if __name__ == "__main__":
    unittest.main()

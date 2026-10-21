import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPORT = Path(__file__).resolve().parents[1] / "digger/scripts/report.py"


class DiggerReportTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.topic = self.root / "topic"
        self.sources = self.topic / "sources"
        self.sources.mkdir(parents=True)
        self.original = "Source title\nA measured value was 12.\nThe sample was small.\n"
        (self.sources / "sample.txt").write_text(self.original, encoding="utf-8")
        self.data = {
            "title": "検証用の抜き書き",
            "question": "何を測ったか",
            "stopped": "原文を確認した",
            "claims": [{
                "claim": "測定値と限界",
                "status": "付いた",
                "quotes": [{
                    "file": "sample.txt",
                    "line": 2,
                    "end": 3,
                    "text": "A measured value was 12. The sample was small.",
                    "ja": "測定値は12で、標本は小さい。",
                    "mark": "〔本人〕測定あり",
                }],
            }],
        }

    def run_report(self, *arguments):
        (self.topic / "extracts.json").write_text(
            json.dumps(self.data, ensure_ascii=False), encoding="utf-8"
        )
        return subprocess.run(
            [sys.executable, str(REPORT), str(self.topic), *arguments],
            capture_output=True, text=True, encoding="utf-8", timeout=10,
        )

    def test_checked_quotes_can_be_rendered_without_changing_the_source(self):
        checked = self.run_report("--check")
        self.assertEqual(checked.returncode, 0, checked.stderr)
        self.assertIn("照合 OK", checked.stdout)
        self.assertFalse((self.topic / "report.html").exists())

        rendered = self.run_report()
        self.assertEqual(rendered.returncode, 0, rendered.stderr)
        page = (self.topic / "report.html").read_text(encoding="utf-8")
        self.assertIn("A measured value was 12. The sample was small.", page)
        self.assertIn("測定値は12で、標本は小さい。", page)
        self.assertIn("sample.txt:2-3", page)
        self.assertEqual(
            (self.sources / "sample.txt").read_text(encoding="utf-8"), self.original
        )

    def test_mismatched_quote_preserves_the_previous_report(self):
        report = self.topic / "report.html"
        report.write_text("previous report", encoding="utf-8")
        self.data["claims"][0]["quotes"][0]["text"] = "A measured value was 99."

        for arguments in [("--check",), ()]:
            with self.subTest(arguments=arguments):
                result = self.run_report(*arguments)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("原文に見つからない", result.stdout)
                self.assertEqual(report.read_text(encoding="utf-8"), "previous report")

    def test_quotes_cannot_read_outside_the_sources_directory(self):
        outside = self.root / "outside.txt"
        outside.write_text(self.original, encoding="utf-8")
        (self.sources / "linked.txt").symlink_to(outside)

        for filename in ["../../outside.txt", str(outside), "linked.txt"]:
            with self.subTest(filename=filename):
                self.data["claims"][0]["quotes"][0]["file"] = filename
                result = self.run_report()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertFalse((self.topic / "report.html").exists())

    def test_markdown_preserves_quotes_links_and_previous_report_on_failure(self):
        self.run_report("--check")
        command = [sys.executable, str(REPORT.with_name("markdown.py")), str(self.topic)]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        output = self.topic / "report.md"
        content = output.read_text()
        self.assertIn("> A measured value was 12. The sample was small.", content)
        self.assertIn("sources/sample.txt", content)
        self.assertIn("訳：測定値は12", content)
        content = content.replace("<!-- digger:related:end -->", "[[wiki/測定]]\n<!-- digger:related:end -->")
        output.write_text(content)
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 0)
        self.assertIn("[[wiki/測定]]", output.read_text())
        previous = output.read_bytes()
        self.data["claims"][0]["quotes"][0]["text"] = "Invented result"
        self.run_report("--check")
        self.assertEqual(subprocess.run(command, capture_output=True).returncode, 1)
        self.assertEqual(output.read_bytes(), previous)
        self.assertEqual((self.sources / "sample.txt").read_text(), self.original)


if __name__ == "__main__":
    unittest.main()

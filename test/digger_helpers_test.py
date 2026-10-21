import importlib.util
import io
import os
import socket
import subprocess
import sys
import tempfile
import unittest
import urllib.request
from pathlib import Path
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / "digger/scripts"


def load(name):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


fetch = load("fetch")
watch = load("watch")
chain = load("chain")


class HelpersTest(unittest.TestCase):
    def test_public_url_boundary_and_redirects(self):
        for module in (fetch, watch):
            for url in ("file:///etc/passwd", "http://127.0.0.1/", "http://[::1]/", "http://user:pass@example.org/"):
                self.assertIsNotNone(module.url_problem(url), url)
            with self.assertRaises(module.UnsafeURL):
                module._Redirect308().redirect_request(
                    urllib.request.Request("https://example.org/"), io.BytesIO(),
                    302, "Found", {}, "http://127.0.0.1/private")
        with self.assertRaises(ValueError):
            chain._SameOrigin().redirect_request(
                urllib.request.Request("https://api.openalex.org/works"), io.BytesIO(),
                302, "Found", {}, "https://other.example/works")

    def test_ocr_requires_explicit_selection(self):
        with patch.dict("os.environ", {}, clear=True), tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(fetch.ocr_if_longer(Path(tmp) / "absent.pdf", "existing text"),
                             ("existing text", "OCRは未選択"))

    def test_failed_fetch_keeps_saved_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            sources = Path(tmp) / "sources"
            sources.mkdir()
            original = sources / "paper.md"
            original.write_text("Keep this original")
            result = subprocess.run([sys.executable, str(SCRIPTS / "fetch.py"), str(sources),
                                     "paper", "http://127.0.0.1/private"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(original.read_text(), "Keep this original")
            self.assertEqual(list(sources.iterdir()), [original])

    def test_feed_parsing_rejects_entities_and_keeps_original_excerpt(self):
        feed = b'<rss><channel><item><title>A title</title><link>https://example.org/a</link><description>Original excerpt</description><pubDate>Wed, 21 Oct 2026 01:00:00 GMT</pubDate></item></channel></rss>'
        entries = watch.items(feed)
        self.assertEqual(entries[0]["title"], "A title")
        self.assertIn("Original excerpt", str(entries[0]))
        with self.assertRaises(ValueError):
            watch.items(b'<!DOCTYPE rss [<!ENTITY secret SYSTEM "file:///etc/passwd">]><rss/>')

    def test_fetch_rejects_truncated_response(self):
        class Response(io.BytesIO):
            headers = {"Content-Type": "text/plain"}
            length = 10

        with patch.object(socket, "getaddrinfo", return_value=[(2, 1, 6, "", ("93.184.215.14", 443))]), \
                patch.object(urllib.request.OpenerDirector, "open", return_value=Response(b"partial")):
            with self.assertRaisesRegex(ValueError, "途中"):
                fetch.download("https://example.org/source")

    def test_subtitle_conversion_preserves_vtt(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            binary = root / "yt-dlp"
            binary.write_text(
                f"#!{sys.executable}\n"
                "import pathlib, sys\n"
                "out = pathlib.Path(sys.argv[sys.argv.index('-o') + 1])\n"
                "out.with_name('v.en.vtt').write_text('WEBVTT\\n\\n00:00:01.000 --> 00:00:03.000\\nOriginal caption.\\n')\n"
                "print('Title\\tAuthor\\t20261021\\ten')\n"
            )
            binary.chmod(0o755)
            with patch.dict(os.environ, {"PATH": str(root) + os.pathsep + os.environ["PATH"]}):
                output = root / "sample.md"
                text = fetch.youtube_to_md("https://www.youtube.com/watch?v=fixture", output)
            self.assertIn("[00:01] Original caption.", text)
            self.assertEqual(output.with_suffix(".vtt").read_text(),
                             "WEBVTT\n\n00:00:01.000 --> 00:00:03.000\nOriginal caption.\n")


if __name__ == "__main__":
    unittest.main()

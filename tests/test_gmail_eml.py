from __future__ import annotations

import importlib.machinery
import importlib.util
import tempfile
import unittest
from email.message import EmailMessage
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("gmail_eml", str(ROOT / "bin" / "gmail-eml"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
gmail_eml = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(gmail_eml)


def sample_message() -> bytes:
    msg = EmailMessage()
    msg["Subject"] = "Evidence export"
    msg["From"] = "sender@example.com"
    msg["To"] = "recipient@example.com"
    msg["Received"] = "by mx2.example"
    msg["Received"] = "by mx1.example"
    msg["DKIM-Signature"] = "v=1; d=example.com; s=test; b=abc"
    msg["Authentication-Results"] = "mx.example; dkim=pass header.d=example.com; spf=pass smtp.mailfrom=example.com"
    msg.set_content("body")
    msg.add_attachment(b"x", maintype="application", subtype="octet-stream", filename="proof.bin")
    return msg.as_bytes()


class GmailEmlTests(unittest.TestCase):
    def test_inspect_reads_complete_headers_and_attachments(self) -> None:
        info = gmail_eml.inspect(sample_message())
        self.assertTrue(info["dkim_sig"])
        self.assertEqual(info["dkim"], "pass")
        self.assertEqual(info["spf"], "pass")
        self.assertEqual(info["received"], 2)
        self.assertEqual(info["attach"], 1)
        self.assertEqual(info["subject"], "Evidence export")

    def test_account_and_message_id_reject_path_components(self) -> None:
        for value in ("../work", "a/b", "..", "/tmp/x"):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    gmail_eml.validate_account(value)
        for value in ("../abc", "abc?format=minimal", "a/b"):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    gmail_eml.validate_message_id(value)

    def test_explicit_output_name_cannot_escape_destination(self) -> None:
        for value in ("../x.eml", "sub/x.eml", "..", ""):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    gmail_eml.explicit_output_name(value)
        self.assertEqual(gmail_eml.explicit_output_name("proof.eml"), "proof.eml")

    def test_export_is_private_and_refuses_overwrite(self) -> None:
        data = sample_message()
        with tempfile.TemporaryDirectory() as tmp:
            with mock.patch.object(gmail_eml, "token", return_value="token"), mock.patch.object(
                gmail_eml, "raw", return_value=data
            ):
                rc = gmail_eml.main(["--account", "default", "--id", "abc123", "--dest", tmp])
                self.assertEqual(rc, 0)
                files = list(Path(tmp).glob("*.eml"))
                self.assertEqual(len(files), 1)
                self.assertEqual(files[0].stat().st_mode & 0o777, 0o600)
                with self.assertRaises(SystemExit) as ctx:
                    gmail_eml.main(["--account", "default", "--id", "abc123", "--dest", tmp])
                self.assertIn("拒绝覆盖", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()

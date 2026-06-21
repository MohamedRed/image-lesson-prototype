#!/usr/bin/env python3
"""Source-level security contracts for ride-sharing Terraform.

These tests intentionally avoid Terraform provider initialization so CI/local agents can
catch unsafe IAM defaults without cloud credentials.
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent
CLOUD_RUN_MODULE = ROOT / "modules" / "cloud_run" / "main.tf"
ROOT_MAIN = ROOT / "main.tf"


class CloudRunSecurityTests(unittest.TestCase):
    def test_public_invoker_is_explicit_opt_in_and_default_private(self) -> None:
        module_text = CLOUD_RUN_MODULE.read_text()
        root_text = ROOT_MAIN.read_text()

        self.assertRegex(
            module_text,
            r'variable\s+"allow_unauthenticated"\s*{[^}]*default\s*=\s*false',
            "Cloud Run module must default to private ingress/invoker IAM",
        )
        self.assertRegex(
            module_text,
            r'resource\s+"google_cloud_run_service_iam_member"\s+"public"\s*{[^}]*count\s*=\s*var\.allow_unauthenticated\s*\?\s*1\s*:\s*0',
            "allUsers invoker IAM must be gated behind allow_unauthenticated",
        )
        self.assertRegex(
            root_text,
            r'(?s)module\s+"planner"\s*{.*?allow_unauthenticated\s*=\s*false',
            "ride planner module call must keep unauthenticated access disabled unless explicitly approved",
        )


if __name__ == "__main__":
    unittest.main()

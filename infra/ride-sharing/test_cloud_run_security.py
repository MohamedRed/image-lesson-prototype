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
ROOT_BACKEND = ROOT / "backend.tf"


class CloudRunSecurityTests(unittest.TestCase):
    def test_root_required_providers_declared_once(self) -> None:
        root_text = ROOT_MAIN.read_text() + "\n" + ROOT_BACKEND.read_text()

        self.assertEqual(
            root_text.count("required_providers"),
            1,
            "Terraform root module must declare required_providers only once so terraform validate can run",
        )

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

    def test_private_planner_grants_invoker_to_cloud_functions_only(self) -> None:
        module_text = CLOUD_RUN_MODULE.read_text()
        root_text = ROOT_MAIN.read_text()

        self.assertRegex(
            module_text,
            r'variable\s+"invoker_members"\s*{[^}]*default\s*=\s*\[\]',
            "Cloud Run module should support explicit invoker members and default to none",
        )
        self.assertRegex(
            module_text,
            r'resource\s+"google_cloud_run_service_iam_member"\s+"invokers"\s*{[^}]*for_each\s*=\s*var\.invoker_members',
            "Cloud Run module should grant invoker IAM only to explicit members",
        )
        self.assertRegex(
            root_text,
            r'(?s)module\s+"planner"\s*{.*?invoker_members\s*=\s*\[.*?serviceAccount:\$\{google_service_account\.cloud_functions\.email\}.*?\]',
            "private planner must grant invoker access to the Cloud Functions service account that calls it",
        )


if __name__ == "__main__":
    unittest.main()

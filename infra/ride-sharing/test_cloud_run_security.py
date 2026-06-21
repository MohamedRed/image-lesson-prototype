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
BIGQUERY_MODULE = ROOT / "modules" / "bigquery" / "main.tf"
MONITORING_BIGQUERY_ALERTS = ROOT / "modules" / "monitoring" / "bigquery_alerts.tf"
MONITORING_MAIN = ROOT / "modules" / "monitoring" / "main.tf"
PUBSUB_MODULE = ROOT / "modules" / "pubsub" / "main.tf"


class CloudRunSecurityTests(unittest.TestCase):
    def test_pubsub_subscription_filter_is_argument_not_dynamic_block(self) -> None:
        pubsub_text = PUBSUB_MODULE.read_text()

        self.assertNotIn(
            'dynamic "filter"',
            pubsub_text,
            "google_pubsub_subscription.filter is an argument, not a nested block",
        )
        self.assertRegex(
            pubsub_text,
            r'(?m)^\s*filter\s*=\s*each\.key\s*==\s*"ride-events"\s*\?',
            "ride-events subscription filter should be assigned with the provider-supported filter argument",
        )

    def test_bigquery_monitoring_does_not_use_basic_auth_uptime_check(self) -> None:
        alerts_text = MONITORING_BIGQUERY_ALERTS.read_text()

        self.assertNotIn(
            'resource "google_monitoring_uptime_check_config" "bigquery_dataset_check"',
            alerts_text,
            "BigQuery API availability should not be modeled as a public/basic-auth uptime check",
        )
        self.assertNotIn(
            "auth_info {",
            alerts_text,
            "Monitoring uptime auth_info is Basic Auth and should not be used with a service account email only",
        )

    def test_bigquery_monitoring_uses_provider_supported_comparison_enums(self) -> None:
        alerts_text = MONITORING_BIGQUERY_ALERTS.read_text()
        allowed_comparisons = {
            '"COMPARISON_GT"',
            '"COMPARISON_GE"',
            '"COMPARISON_LT"',
            '"COMPARISON_LE"',
            '"COMPARISON_EQ"',
            '"COMPARISON_NE"',
        }
        comparisons = re.findall(r'comparison\s*=\s*("[^"]+")', alerts_text)

        self.assertNotIn(
            '"COMPARISON_LESS_THAN"',
            comparisons,
            "Terraform google provider expects COMPARISON_LT, not COMPARISON_LESS_THAN",
        )
        self.assertTrue(comparisons, "BigQuery alert policies should declare comparison enums")
        self.assertTrue(
            set(comparisons).issubset(allowed_comparisons),
            f"Unsupported monitoring comparison enums: {sorted(set(comparisons) - allowed_comparisons)}",
        )

    def test_bigquery_monitoring_alerts_use_declared_notification_channel(self) -> None:
        alerts_text = MONITORING_BIGQUERY_ALERTS.read_text()
        monitoring_text = MONITORING_MAIN.read_text()

        self.assertIn(
            'resource "google_monitoring_notification_channel" "slack"',
            monitoring_text,
            "monitoring module should declare the Slack notification channel used by alerts",
        )
        self.assertNotIn(
            "google_monitoring_notification_channel.slack_alerts",
            alerts_text,
            "BigQuery alert policies must not reference an undeclared slack_alerts channel",
        )
        self.assertIn(
            "google_monitoring_notification_channel.slack.id",
            alerts_text,
            "BigQuery alert policies should use the declared Slack notification channel id",
        )

    def test_bigquery_procedure_path_resolves_inside_ride_sharing_config(self) -> None:
        module_text = BIGQUERY_MODULE.read_text()

        self.assertIn(
            'definition_body = file("${path.module}/../../bigquery_procedures.sql")',
            module_text,
            "BigQuery routine should load the SQL file that is checked into infra/ride-sharing",
        )
        self.assertTrue(
            (ROOT / "bigquery_procedures.sql").is_file(),
            "BigQuery procedure SQL file must be distributed with the Terraform configuration",
        )

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

    def test_cloud_run_service_account_is_passed_from_root_resource(self) -> None:
        module_text = CLOUD_RUN_MODULE.read_text()
        root_text = ROOT_MAIN.read_text()

        self.assertNotIn(
            'data "google_service_account" "cloud_run"',
            module_text,
            "Cloud Run module must not data-source lookup a service account created by the same root plan",
        )
        self.assertRegex(
            module_text,
            r'variable\s+"service_account_email"\s*{[^}]*type\s*=\s*string',
            "Cloud Run module should accept the service account email from its caller",
        )
        self.assertIn(
            "service_account = var.service_account_email",
            module_text,
            "Cloud Run revision should run as the explicitly passed service account",
        )
        self.assertRegex(
            root_text,
            r'(?s)module\s+"planner"\s*{.*?service_account_email\s*=\s*google_service_account\.cloud_run\.email',
            "root planner module call should pass the service account resource email to create a Terraform dependency",
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

#!/usr/bin/env python3
"""Static guardrails for Liive Ride Android visual parity.

These checks cover small, high-impact typography/spacing decisions that are easy
for CI to verify and that protect the Appetize/Claude parity evidence.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRIVER_CARD = ROOT / "app/src/main/java/com/liive/ride/designsystem/LiiveDriverCard.kt"

source = DRIVER_CARD.read_text()

required_snippets = {
    "driver name should use titleMedium so `John Driver` does not truncate in the Pixel/Appetize card":
        "style = MaterialTheme.typography.titleMedium,",
    "driver card row spacing should be compact enough for Pixel/Appetize width":
        "val RowSpacing = LiiveSpacing.s + LiiveSpacing.xs2",
    "driver avatar should keep a compact but touch-safe 52dp footprint":
        "val AvatarSize = LiiveControl.lg + LiiveSpacing.xs2",
}

missing = [message for message, snippet in required_snippets.items() if snippet not in source]
if missing:
    for message in missing:
        print(f"visual parity check failed: {message}")
    raise SystemExit(1)

print("visual-parity-checks-passed")

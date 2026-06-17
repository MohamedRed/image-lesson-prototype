package com.liive.ride.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.liive.ride.*
import com.liive.ride.designsystem.*

@Composable
fun RideDestinationSheet(onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    LiiveBottomSheet(modifier = Modifier.testTag(RideTestTags.DestinationSheet)) {
        Row(Modifier.fillMaxWidth().padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Where to?", color = c.text, style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.weight(1f))
            Text(
                "Now ▾",
                color = c.accent,
                style = MaterialTheme.typography.titleMedium.copy(fontSize = 14.sp),
                fontWeight = FontWeight.SemiBold
            )
        }

        Row(
            Modifier.fillMaxWidth().height(46.dp).clip(LiiveRadius.md).background(c.fillTertiary).padding(horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Icon(painterResource(RideIcons.Search), null, tint = c.textSecondary, modifier = Modifier.size(18.dp))
            Text("Search a place or address", color = c.textTertiary, style = MaterialTheme.typography.bodyMedium)
        }

        Spacer(Modifier.height(14.dp))
        Column(Modifier.fillMaxWidth().clip(LiiveRadius.lg).background(c.surfaceRaised)) {
            RideFixtures.destinations.forEachIndexed { index, place ->
                LiiveListRow(
                    title = place.title,
                    subtitle = place.subtitle,
                    divider = index < RideFixtures.destinations.lastIndex,
                    chevron = true,
                    leading = { LiiveIconCircle(place.icon, color = place.color, size = 36.dp) },
                    onClick = { onEvent(RideEvent.SelectDestination(place)) }
                )
            }
        }
    }
}

@Composable
fun RideOptionsSheet(state: RideUiState, onEvent: (RideEvent) -> Unit) {
    val c = LiiveTheme.colors
    LiiveBottomSheet(modifier = Modifier.testTag(RideTestTags.OptionsSheet)) {
        Row(Modifier.fillMaxWidth().padding(bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(32.dp).clip(LiiveRadius.full).background(c.fillTertiary)
                    .clickableNoRipple { onEvent(RideEvent.BackToDestination) },
                contentAlignment = Alignment.Center
            ) {
                Icon(painterResource(RideIcons.ChevronLeft), null, tint = c.text, modifier = Modifier.size(20.dp))
            }
            Spacer(Modifier.width(10.dp))
            Column(Modifier.weight(1f)) {
                Text("Choose your ride", color = c.text, style = MaterialTheme.typography.headlineSmall)
                Text("to ${state.destination?.title ?: "Union Square"}", color = c.textSecondary, style = MaterialTheme.typography.bodySmall)
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(bottom = 14.dp)) {
            RideTier.entries.forEach { tier ->
                RideTierRow(tier = tier, selected = tier == state.config.tier) { onEvent(RideEvent.SelectTier(tier)) }
            }
        }

        Column(Modifier.fillMaxWidth().clip(LiiveRadius.lg).background(c.surfaceRaised)) {
            LiiveListRow(
                title = "Passengers",
                leading = { LiiveIconCircle(RideFixtures.passengerIcon, IconCircleColor.Neutral, 32.dp) },
                trailing = { LiiveStepper(state.config.passengers, 1..4) { onEvent(RideEvent.SetPassengers(it)) } }
            )
            LiiveListRow(
                title = "Bags",
                leading = { LiiveIconCircle(RideFixtures.bagIcon, IconCircleColor.Neutral, 32.dp) },
                trailing = { LiiveStepper(state.config.bags, 0..4) { onEvent(RideEvent.SetBags(it)) } }
            )
            LiiveListRow(
                title = "Female-only pool",
                subtitle = "Match same-gender drivers & riders",
                leading = { LiiveIconCircle(RideFixtures.safetyIcon, IconCircleColor.Success, 32.dp) },
                trailing = { LiiveSwitch(state.config.femaleOnly) { onEvent(RideEvent.SetFemaleOnly(it)) } }
            )
            LiiveListRow(
                title = "Child seat",
                divider = false,
                leading = { LiiveIconCircle(RideFixtures.childSeatIcon, IconCircleColor.Neutral, 32.dp) },
                trailing = { LiiveSwitch(state.config.childSeat) { onEvent(RideEvent.SetChildSeat(it)) } }
            )
        }
        Spacer(Modifier.height(14.dp))
        LiiveButton(
            title = "Confirm Pickup · ${state.config.tier.price.ridePrice()}",
            onClick = { onEvent(RideEvent.ConfirmPickup) },
            fullWidth = true,
            size = LiiveButtonSize.Lg,
            capsule = true,
            tabularNumbers = true
        )
    }
}

@Composable
private fun RideTierRow(tier: RideTier, selected: Boolean, onClick: () -> Unit) {
    val c = LiiveTheme.colors
    Row(
        Modifier.fillMaxWidth()
            .clip(LiiveRadius.lg)
            .background(c.surfaceRaised)
            .border(1.5.dp, if (selected) c.accent else Color.Transparent, LiiveRadius.lg)
            .clickableNoRipple(onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        LiiveIconCircle(tier.icon, color = if (selected) IconCircleColor.Accent else IconCircleColor.Neutral)
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(tier.displayName, color = c.text, style = MaterialTheme.typography.titleLarge)
                if (tier.multiLeg) LiiveBadge("2 legs", BadgeColor.Warning)
            }
            Text(tier.detail, color = c.textSecondary, style = MaterialTheme.typography.bodySmall)
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                tier.price.ridePrice(),
                color = c.text,
                style = MaterialTheme.typography.titleLarge.tabularNumbers(),
                fontWeight = FontWeight.Bold
            )
            Text(tier.eta, color = c.textSecondary, style = MaterialTheme.typography.labelMedium.tabularNumbers())
        }
    }
}

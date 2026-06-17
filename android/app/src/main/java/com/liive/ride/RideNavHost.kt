package com.liive.ride

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

@Composable
internal fun RideNavHost(modifier: Modifier = Modifier) {
    val navController = rememberNavController()

    NavHost(
        navController = navController,
        startDestination = RideRoute.Rider,
        modifier = modifier
    ) {
        composable(RideRoute.Rider) {
            RideApp(viewModel = hiltViewModel())
        }
    }
}

private object RideRoute {
    const val Rider = "rider"
}

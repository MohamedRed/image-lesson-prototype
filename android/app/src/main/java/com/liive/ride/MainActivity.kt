package com.liive.ride

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.remember
import androidx.core.view.WindowCompat
import androidx.lifecycle.viewmodel.compose.viewModel

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        setContent {
            val stateStore = remember { RideStateStore(applicationContext) }
            val viewModel: RideViewModel = viewModel(
                factory = RideViewModel.factory(stateStore)
            )
            RideApp(viewModel)
        }
    }
}

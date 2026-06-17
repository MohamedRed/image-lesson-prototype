//
//  LiiveRideApp.swift
//  Liive Ride
//
//  Created by MRR on 2025-06-12.
//

import SwiftUI
import RideSharingFeature

@main
struct LiiveRideApp: App {
    var body: some Scene {
        WindowGroup {
            LiiveRideFeature.mockAppView()
        }
    }
}

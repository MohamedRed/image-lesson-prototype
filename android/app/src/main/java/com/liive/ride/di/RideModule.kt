package com.liive.ride.di

import com.liive.ride.MockRideService
import com.liive.ride.RideService
import com.liive.ride.RideStateStore
import com.liive.ride.RideStateStoring
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
internal abstract class RideModule {
    @Binds
    @Singleton
    abstract fun bindRideService(service: MockRideService): RideService

    @Binds
    @Singleton
    abstract fun bindRideStateStore(store: RideStateStore): RideStateStoring
}

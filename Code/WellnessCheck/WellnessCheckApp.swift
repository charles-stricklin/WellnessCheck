//
//  WellnessCheckApp.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/11/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

@main
struct WellnessCheckApp: App {
	// Initialize Firebase when the app launches
	init() {
		FirebaseApp.configure()
	}

	var body: some Scene {
		WindowGroup {
			SplashView() // Entry point → splash screen
		}
	}
}

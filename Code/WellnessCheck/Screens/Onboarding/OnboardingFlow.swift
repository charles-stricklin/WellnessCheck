//
//  OnboardingFlow.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/11/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

struct OnboardingFlow: View {
	var body: some View {
		NavigationView {
			VStack {
				Text("Welcome to WellnessCheck")
					.font(.title)
					.padding()

				Text("Your safety, health, and peace of mind are our priority.")
					.font(.subheadline)
					.multilineTextAlignment(.center)
					.padding()

				Spacer()

				NavigationLink("Continue") {
					ContentView()
				}
				.padding()
				.buttonStyle(.borderedProminent)
			}
		}
	}
}

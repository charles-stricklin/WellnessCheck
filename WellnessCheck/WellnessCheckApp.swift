// WellnessCheckApp.swift
// WellnessCheck
//
// Created by Charles Stricklin
//
// Root app entry point
//

import SwiftUI

@main
struct WellnessCheckApp: App {
	@State private var onboardingStep = 0

	var body: some Scene {
		WindowGroup {
			OnboardingFlow(
				currentStep: $onboardingStep,
				totalSteps: 7
			)
		}
	}
}

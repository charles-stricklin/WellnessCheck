//
//  OnboardingStepTwo.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/17/25.
//  Version: v0.002a
//
//  Purpose: Second onboarding screen. Introduces the need for permissions
//  (like notifications) to keep the app functional. Navigation scaffolded.
//
//  Changelog:
//  /// Added: Step two onboarding screen with navigation
//  /// Updated: Replaced deprecated NavigationLink(isActive:) with navigationDestination
//  /// Bug Fixes: N/A
//

import SwiftUI

struct OnboardingStepTwo: View {
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
	let totalSteps: Int
	@State private var goNext: Bool = false

	var body: some View {
		NavigationStack {
			GlassBackgroundView {
				VStack(spacing: 20) {
					Spacer()

					Text("To keep you safe, WellnessCheck may need permissions like Notifications.")
						.font(.title3.weight(.semibold))
						.multilineTextAlignment(.center)
						.padding(.horizontal)

					Text("We’ll guide you through these requests. You can always adjust them later in Settings.")
						.font(.subheadline)
						.multilineTextAlignment(.center)
						.foregroundStyle(.secondary)
						.padding(.horizontal)

					Spacer()

					Button("Continue") {
						goNext = true
					}
					.buttonStyle(.borderedProminent)

					ProgressDotsView(totalSteps: totalSteps, currentStep: 2)
						.padding(.top, 12)

					Spacer()
				}
			}
			.navigationDestination(isPresented: $goNext) {
				Text("Onboarding Step 3 Placeholder") // replace later
			}
		}
	}
}

#Preview {
	// OnboardingStepTwo(totalSteps: WellnessCheckApp.totalOnboardingSteps)
}

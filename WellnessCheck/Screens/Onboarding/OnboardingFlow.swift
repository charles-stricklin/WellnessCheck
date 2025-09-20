//
//  OnboardingFlow.swift
//  WellnessCheck
//
//  Created by Charles Stricklin
//  Version: v0.18a
//

import SwiftUI

struct OnboardingFlow: View {
	@Binding var currentStep: Int
	let totalSteps: Int

	var body: some View {
		TabView(selection: $currentStep) {
			OnboardingStepOne(selection: $currentStep) // ✅ binding passed
				.tag(0)

			// Placeholder steps
			Text("Step 2")
				.tag(1)

			Text("Step 3")
				.tag(2)
		}
		.tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
	}
}

#Preview {
	OnboardingFlow(
		currentStep: .constant(0),
		totalSteps: 7
	)
}

//
//  OnboardingStepOne.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/20/25
//  Version: v0.004a
//
//  Purpose:
//  First onboarding screen. Displays logo, tagline, and a
//  “Get Started” button that advances onboarding flow.
//
//  Changelog:
//  - Added @Binding var selection to sync with OnboardingFlow
//  - Button now sets selection = 1 to advance to next step
//  - Still uses custom LiquidGlassBackground for styling
//

import SwiftUI

struct OnboardingStepOne: View {
	@Binding var selection: Int   // passed in from OnboardingFlow

	var body: some View {
		ZStack {
			// Full edge-to-edge background
			Image("OnboardingBackground")
				.resizable()
				.scaledToFill()
				.ignoresSafeArea()

			VStack {
				Spacer(minLength: 60)

				Image("WCLogo")
					.resizable()
					.scaledToFit()
					.frame(width: 140, height: 140)
					.shadow(radius: 6)

				Text("Welcome to WellnessCheck")
					.font(.title.bold())
					.multilineTextAlignment(.center)
					.foregroundColor(.primary)
					.padding(.horizontal, 24)

				Text("Peace of Mind — Without Lifting a Finger")
					.font(.callout)
					.multilineTextAlignment(.center)
					.foregroundColor(.secondary)
					.padding(.horizontal, 32)

				Text("Next: Add your first contact")
					.font(.footnote)
					.foregroundColor(.secondary)
					.padding(.top, 8)

				// Glass-style button advances flow
				Button(action: {
					selection = 1   // go to Step 2
				}) {
					Text("Get Started")
						.font(.headline)
						.frame(maxWidth: .infinity)
						.padding()
				}
				.modifier(LiquidGlassBackground(cornerRadius: 16))
				.padding(.horizontal, 40)
				.padding(.top, 16)

				Spacer()
			}
			.padding(.horizontal, 20)
			.padding(.top, 40)
		}
	}
}

#Preview {
	OnboardingStepOne(selection: .constant(0))
		.preferredColorScheme(.light)

	OnboardingStepOne(selection: .constant(0))
		.preferredColorScheme(.dark)
}

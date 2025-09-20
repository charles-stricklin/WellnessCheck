//
//  ProgressDotsView.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 2025-09-16
//  Version: v0.003a
//
//  Purpose: Reusable onboarding progress indicator. Shows N dots
//  with the current step highlighted. No background—meant to sit
//  inside the glass container.
//
//  Changelog:
//  /// Added: Accessibility labels per dot
//  /// Updated: Simplified (no background) to avoid nested panes
//  /// Bug Fixes: None
//

import SwiftUI

struct ProgressDotsView: View {
	let totalSteps: Int
	let currentStep: Int  // 1-based index

	var body: some View {
		HStack(spacing: 8) {
			ForEach(1...max(totalSteps, 1), id: \.self) { step in
				Circle()
					.fill(step == currentStep ? Color.white : Color.white.opacity(0.3))
					.frame(width: 8, height: 8)
					.accessibilityLabel("Step \(step) of \(totalSteps)")
					.accessibilityAddTraits(step == currentStep ? .isSelected : [])
			}
		}
	}
}

#Preview {
	ZStack {
		Color.black.ignoresSafeArea()
		ProgressDotsView(totalSteps: 7, currentStep: 3)
	}
	.preferredColorScheme(.dark)
}

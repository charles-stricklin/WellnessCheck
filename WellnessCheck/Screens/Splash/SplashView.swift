//
//  SplashView.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/11/25.
//  Version: v0.002a
//
//  Purpose: Splash screen shown after onboarding is complete.
//  Provides a quick branding moment before main app content loads.
//
//  Changelog:
//  /// Added: Initial splash view
//  /// Updated: Removed nil-coalescing operator warning on Color
//  /// Bug Fixes: Cleaned up background rendering
//

import SwiftUI

struct SplashView: View {
	@State private var isActive: Bool = false

	var body: some View {
		ZStack {
			// Background
			Color("Background")
				.ignoresSafeArea()

			// Branding content
			VStack {
				Image("WCLogo") // Make sure this asset exists in Assets.xcassets
					.resizable()
					.scaledToFit()
					.frame(width: 180, height: 180)

				Text("WellnessCheck")
					.font(.largeTitle.bold())
					.foregroundColor(Color("PrimaryText")) // Replace with your color set
					.padding(.top, 20)
			}
			.opacity(isActive ? 1 : 0)
			.animation(.easeIn(duration: 0.6), value: isActive)
		}
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
				withAnimation {
					isActive = true
				}
			}
		}
	}
}

#Preview {
	SplashView()
}

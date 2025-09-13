//
//  SplashView.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/11/25.
//

import SwiftUI

struct SplashView: View {
	@State private var isActive = false
	@State private var fadeIn = 0.0

	var body: some View {
		Group {
			if isActive {
				ContentView() // transition target
					.transition(.opacity)
			} else {
				ZStack {
					// Background color from assets; graceful fallback if asset missing
					(Color("Background", bundle: .main).opacity(1.0))
						.ignoresSafeArea()

					VStack(spacing: 20) {
						// Logo
						Image("WCLogo")
							.resizable()
							.scaledToFit()
							.frame(width: 150, height: 150)

						VStack(spacing: 4) {
							Text("WellnessCheck")
								.font(.title).bold()
								.foregroundColor(color("PrimaryText"))

							Text("Version 1.0")
								.font(.footnote) // smaller than subheadline
								.foregroundColor(color("PrimaryText").opacity(0.85))
						}
					}
					.opacity(fadeIn)
				}
				.onAppear {
					withAnimation(.easeIn(duration: 1.0)) { fadeIn = 1.0 }
					DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
						withAnimation { isActive = true }
					}
				}
			}
		}
	}

	/// Safe color loader: uses asset if present, falls back to .primary
	private func color(_ name: String) -> Color {
		Color(name, bundle: .main) ?? Color.primary
	}
}

#Preview {
	SplashView()
}

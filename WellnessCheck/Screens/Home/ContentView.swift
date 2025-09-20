//
//  ContentView.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/11/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

struct ContentView: View {
	var body: some View {
		VStack(spacing: 20) {
			Text("🔥 WellnessCheck Firebase Test 🔥")
				.font(.title)
				.bold()
				.multilineTextAlignment(.center)
				.padding()

			Text("If you see events in Firebase DebugView, it’s working ✅")
				.font(.body)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)

			Button("Log Custom Test Event") {
				Analytics.logEvent("custom_test_event", parameters: [
					"screen": "ContentView",
					"time": "\(Date())"
				])
				print("✅ Logged custom_test_event")
			}
			.buttonStyle(.borderedProminent)
			.tint(.blue)
		}
		.padding()
		.onAppear {
			// Log automatically when the view appears
			Analytics.logEvent("contentview_appeared", parameters: [
				"screen": "ContentView"
			])
			print("✅ Logged contentview_appeared")
		}
	}
}

#Preview {
	ContentView()
}

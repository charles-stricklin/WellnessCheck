//
//  GlassBackgroundView.swift
//  WellnessCheck
//
//  Created by Charles Stricklin
//  Version: v0.14b
//
//  Purpose:
//  Provides reusable glass-style backgrounds for containers and buttons.
//
//  Changelog:
//  /// Added: LiquidGlassBackground ViewModifier for smaller UI elements
//  /// Bug Fixes: Ensured both GlassBackgroundView and LiquidGlassBackground
//               are defined in one file for global scope access
//

import SwiftUI

// MARK: - GlassBackgroundView
struct GlassBackgroundView<Content: View>: View {
	let content: Content

	init(@ViewBuilder content: () -> Content) {
		self.content = content()
	}

	var body: some View {
		content
			.padding(16)
			.background(.ultraThinMaterial,
						in: RoundedRectangle(cornerRadius: 24, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: 24, style: .continuous)
					.stroke(Color.white.opacity(0.12), lineWidth: 1)
			)
			.shadow(color: Color.black.opacity(0.18), radius: 20, x: 0, y: 10)
	}
}

// MARK: - LiquidGlassBackground
struct LiquidGlassBackground: ViewModifier {
	var cornerRadius: CGFloat = 16

	func body(content: Content) -> some View {
		content
			.padding(8)
			.background(.ultraThinMaterial,
						in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.stroke(Color.white.opacity(0.12), lineWidth: 1)
			)
			.shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
	}
}

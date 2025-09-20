//
//  UserModel.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/17/25.
//  Version: v0.002a
//
//  Purpose: Core data model for WellnessCheck. Stores basic
//  user info, caregiver contacts, and preferences locally.
//  This replaces the default Item.swift template.
//
//  Changelog:
//  /// Added: UserModel with Codable + Identifiable
//  /// Updated: Made caregiver fields optional, added safe defaults
//  /// Bug Fixes: Fixed UUID initializer syntax
//

import Foundation

/// Represents a single caregiver contact
struct Caregiver: Identifiable, Codable, Hashable {
	var id: UUID = UUID()
	var name: String
	var phoneNumber: String? = nil
	var relationship: String? = nil
}

/// Represents the primary user of WellnessCheck
struct UserModel: Identifiable, Codable, Hashable {
	var id: UUID = UUID()
	var name: String = ""                       // default empty, filled in onboarding
	var caregivers: [Caregiver] = []            // starts empty
	var inactivityTimeoutHours: Int = 6         // sensible default
	var warningsBeforeAlert: Int = 1            // sensible default
	var createdAt: Date = Date()
}

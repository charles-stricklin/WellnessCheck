//
//  WellnessCheckApp.swift
//  WellnessCheck
//
//  Created by Charles Stricklin on 9/11/25.
//

import Foundation
import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

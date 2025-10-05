//
//  AnalyticsImports.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/10/25.
//

// This file ensures all Analytics components are properly imported
// Import this file in your main app to access all analytics features

import Foundation
import SwiftUI

// Re-export all analytics components for easy access
typealias Analytics_View = AnalyticsView
typealias Analytics_ChartsView = AnalyticsChartsView
typealias Analytics_DataView = AnalyticsDataView
typealias Analytics_Service = AnalyticsService

// Make sure all models are accessible
typealias Analytics_AcademicEvent = AcademicEvent
typealias Analytics_Course = Course
typealias Analytics_EventType = EventType
typealias Analytics_EventStatus = EventStatus
typealias Analytics_Priority = Priority
typealias Analytics_UrgencyLevel = UrgencyLevel

// Analytics response types
typealias Analytics_HighestWeightEventResponse = HighestWeightEventResponse
typealias Analytics_StudentAnalyticsData = StudentAnalyticsData

// Analytics errors
typealias Analytics_Error = AnalyticsError
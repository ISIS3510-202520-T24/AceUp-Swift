//
//  PlannerTaskDataProviderProtocol.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import Foundation

/// Protocol for planner task data persistence
protocol PlannerTaskDataProviderProtocol: AnyObject {
    func fetchAll() async throws -> [PlannerTask]
    func fetchById(_ id: String) async throws -> PlannerTask?
    func fetchByDateRange(from: Date, to: Date) async throws -> [PlannerTask]
    func fetchByStatus(_ status: PlannerTaskStatus) async throws -> [PlannerTask]
    func save(_ task: PlannerTask) async throws
    func update(_ task: PlannerTask) async throws
    func delete(_ id: String) async throws
}

//
//  PlannerTaskRowView.swift
//  AceUP-Swift
//
//  Created by Ángel Farfán Arcila on 4/12/25.
//

import SwiftUI

struct PlannerTaskRowView: View {
    let task: PlannerTask
    let onTap: () -> Void
    let onComplete: () -> Void
    let onInProgress: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(Color(hex: task.status.color))
                    .frame(width: 12, height: 12)
                
                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(UI.navy)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        // Category icon
                        HStack(spacing: 4) {
                            Image(systemName: task.category.icon)
                                .font(.caption)
                            Text(task.category.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(UI.muted)
                        
                        if let courseName = task.courseName {
                            Text("•")
                                .foregroundColor(UI.muted)
                            
                            Text(courseName)
                                .font(.caption)
                                .foregroundColor(Color(hex: task.courseColor ?? UI.primary.toHex()))
                        }
                        
                        if task.estimatedDuration != nil {
                            Text("•")
                                .foregroundColor(UI.muted)
                            
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                Text(task.formattedDuration)
                                    .font(.caption)
                            }
                            .foregroundColor(UI.muted)
                        }
                    }
                    
                    // Priority badge
                    if task.priority == .critical || task.priority == .high {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                            Text(task.priority.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: task.priority.color))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Action buttons
                if task.status == .planned {
                    Button(action: onInProgress) {
                        Image(systemName: "play.circle")
                            .font(.title3)
                            .foregroundColor(UI.primary)
                    }
                    .buttonStyle(.plain)
                }
                
                if task.status != .completed {
                    Button(action: onComplete) {
                        Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(task.status == .completed ? UI.success : UI.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 12) {
        PlannerTaskRowView(
            task: PlannerTask(
                title: "Study Algorithms",
                description: "Review sorting algorithms",
                courseId: "cs101",
                courseName: "Computer Science",
                courseColor: "#42A5F5",
                scheduledDate: Date(),
                estimatedDuration: 7200,
                priority: .high,
                status: .planned,
                category: .study
            ),
            onTap: {},
            onComplete: {},
            onInProgress: {}
        )
        
        PlannerTaskRowView(
            task: PlannerTask(
                title: "Complete Assignment",
                scheduledDate: Date(),
                status: .inProgress,
                category: .assignment
            ),
            onTap: {},
            onComplete: {},
            onInProgress: {}
        )
    }
    .padding()
    .background(UI.neutralLight)
}

# AceUp Swift - Firestore Database Schema

This document outlines the complete Firestore database schema for the AceUp Swift application, organized by implementation phases.

## Phase 1 - Core Academic Data

### 1. Users Collection (`users`)
**Current Implementation Status:** ✅ Implemented
```json
{
  "uid": "string",           // Firebase Auth UID
  "email": "string",         // User email
  "nick": "string",          // Display name/username
  "createdAt": "timestamp"   // Account creation date
}
```

### 2. Assignments Collection (`assignments`)
**Implementation Status:** 🚧 In Progress
```json
{
  "id": "string",               // Assignment ID
  "userId": "string",           // Owner UID
  "title": "string",            // Assignment title
  "description": "string?",     // Optional description
  "courseId": "string",         // Course identifier
  "courseName": "string",       // Course display name
  "courseColor": "string",      // Course theme color
  "dueDate": "timestamp",       // Due date
  "weight": "number",           // Grade weight (0.0-1.0)
  "estimatedHours": "number?",  // Estimated time
  "actualHours": "number?",     // Actual time spent
  "priority": "string",         // low, medium, high, critical
  "status": "string",           // pending, in_progress, completed, etc.
  "tags": ["string"],           // Assignment tags
  "attachments": [{             // File attachments
    "id": "string",
    "name": "string",
    "url": "string",
    "type": "string",
    "size": "number?",
    "uploadedAt": "timestamp"
  }],
  "subtasks": [{               // Sub-tasks
    "id": "string",
    "title": "string",
    "description": "string?",
    "isCompleted": "boolean",
    "estimatedHours": "number?",
    "completedAt": "timestamp?",
    "createdAt": "timestamp"
  }],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 3. Courses Collection (`courses`)
**Implementation Status:** 🚧 In Progress
```json
{
  "id": "string",               // Course ID
  "userId": "string",           // Student UID
  "name": "string",             // Course name
  "code": "string",             // Course code (CS101, etc.)
  "credits": "number",          // Credit hours
  "instructor": "string",       // Professor name
  "color": "string",            // Theme color
  "semester": "string",         // Fall, Spring, etc.
  "year": "number",             // Academic year
  "gradeWeight": {              // Grade distribution
    "assignments": "number",
    "exams": "number",
    "projects": "number",
    "participation": "number",
    "other": "number"
  },
  "currentGrade": "number?",    // Current grade
  "targetGrade": "number?",     // Target grade
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Phase 2 - Enhanced Features

### 4. Groups Collection (`groups`)
**Current Implementation Status:** ✅ Implemented
```json
{
  "name": "string",          // Group name
  "ownerId": "string",       // Creator's UID
  "members": ["string"],     // Array of member UIDs
  "createdAt": "timestamp",  // Creation date
  "isPublic": "boolean",     // Public/private group
  "description": "string",   // Group description
  "color": "string",         // Group theme color
  "inviteCode": "string?"    // QR code for joining
}
```

### 5. Calendar Events Collection (`calendar_events`)
**Implementation Status:** 📋 Planned
```json
{
  "id": "string",               // Event ID
  "userId": "string",           // Creator UID
  "groupId": "string?",         // Optional group
  "title": "string",            // Event title
  "description": "string?",     // Description
  "startTime": "timestamp",     // Start time
  "endTime": "timestamp",       // End time
  "type": "string",             // Event type
  "priority": "string",         // Priority
  "isShared": "boolean",        // Shared with group
  "attendees": ["string"],      // Attendee UIDs
  "location": "string?",        // Location
  "isRecurring": "boolean",     // Recurring event
  "recurrencePattern": {        // Recurrence rules
    "frequency": "string",
    "interval": "number",
    "daysOfWeek": ["number"]?,
    "endDate": "timestamp?",
    "occurrenceCount": "number?"
  }?,
  "reminderMinutes": ["number"], // Reminder times
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 6. User Availability Collection (`user_availability`)
**Implementation Status:** 📋 Planned
```json
{
  "userId": "string",           // User UID
  "availability": [{            // Weekly availability slots
    "id": "string",
    "dayOfWeek": "number",      // 0-6 (Sunday-Saturday)
    "startTime": {
      "hour": "number",
      "minute": "number"
    },
    "endTime": {
      "hour": "number",
      "minute": "number"
    },
    "title": "string?",
    "type": "string",           // free, busy, lecture, etc.
    "priority": "string"
  }],
  "updatedAt": "timestamp"
}
```

### 7. Workload Analysis Collection (`workload_analysis`)
**Implementation Status:** 📋 Planned
```json
{
  "id": "string",               // Analysis ID
  "userId": "string",           // User UID
  "analysisDate": "timestamp",  // Analysis date
  "totalAssignments": "number", // Total pending assignments
  "averageDaily": "number",     // Average daily workload
  "workloadBalance": "string",  // excellent, good, fair, poor
  "overloadDays": ["timestamp"], // Days with too much work
  "lightDays": ["timestamp"],   // Days with light work
  "recommendations": ["string"], // Generated recommendations
  "dailyWorkload": "object",    // Daily distribution map
  "createdAt": "timestamp"
}
```

## Phase 3 - Intelligence & Analytics

### 8. Smart Recommendations Collection (`smart_recommendations`)
**Implementation Status:** 📋 Planned
```json
{
  "id": "string",               // Recommendation ID
  "userId": "string",           // User UID
  "type": "string",             // recommendation type
  "title": "string",            // Title
  "message": "string",          // Recommendation message
  "priority": "string",         // Priority level
  "actionable": "boolean",      // Can user act on it
  "suggestedAction": "string?", // Suggested action
  "relatedAssignments": ["string"], // Related assignment IDs
  "isRead": "boolean",          // Has user seen it
  "isActedUpon": "boolean",     // Has user acted on it
  "createdAt": "timestamp",
  "expiresAt": "timestamp?"     // Optional expiration
}
```

### 9. User Analytics Data Collection (`user_analytics`)
**Implementation Status:** 📋 Planned
```json
{
  "userId": "string",           // User UID
  "lastUpdated": "timestamp",   // Last sync
  "completionRate": "number",   // Assignment completion %
  "averageGrade": "number?",    // Average grade
  "productivityScore": "number", // Productivity metric
  "studyHours": {               // Study time tracking
    "totalHours": "number",
    "weeklyAverage": "number",
    "monthlyGoal": "number?"
  },
  "preferences": {              // User preferences
    "reminderFrequency": "string",
    "workloadThreshold": "number",
    "preferredStudyTimes": ["string"]
  },
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### 10. User Settings Collection (`user_settings`)
**Implementation Status:** 📋 Planned
```json
{
  "userId": "string",           // User UID
  "notifications": {            // Notification preferences
    "assignments": "boolean",
    "deadlines": "boolean",
    "groupUpdates": "boolean",
    "smartSuggestions": "boolean"
  },
  "privacy": {                  // Privacy settings
    "shareAvailability": "boolean",
    "publicProfile": "boolean",
    "allowGroupInvites": "boolean"
  },
  "appearance": {               // UI preferences
    "theme": "string",          // light, dark, auto
    "accentColor": "string",
    "language": "string"
  },
  "workload": {                 // Workload preferences
    "maxDailyAssignments": "number",
    "workingHours": {
      "start": "string",        // "09:00"
      "end": "string"           // "17:00"
    },
    "timezone": "string"
  },
  "updatedAt": "timestamp"
}
```

## Phase 4 - Performance & Caching

### 11. Holiday Cache Collection (`holidays`)
**Implementation Status:** 📋 Planned
```json
{
  "id": "string",               // Holiday ID
  "countryCode": "string",      // Country code
  "date": "string",             // yyyy-MM-dd format
  "localName": "string",        // Local name
  "name": "string",             // English name
  "fixed": "boolean?",          // Fixed date
  "global": "boolean?",         // Global holiday
  "counties": ["string"]?,      // Specific counties
  "launchYear": "number?",      // First year
  "types": ["string"]?,         // Holiday types
  "cachedAt": "timestamp"       // Cache timestamp
}
```

### 12. Academic Events Collection (`academic_events`)
**Implementation Status:** 📋 Planned
```json
{
  "id": "string",               // Event ID
  "userId": "string",           // Owner UID
  "title": "string",            // Event title
  "description": "string?",     // Description
  "courseId": "string",         // Related course
  "courseName": "string",       // Course name
  "type": "string",             // assignment, exam, project, etc.
  "dueDate": "timestamp",       // Due date
  "weight": "number",           // Grade weight
  "status": "string",           // pending, completed, etc.
  "priority": "string",         // Priority level
  "estimatedHours": "number?",  // Time estimate
  "actualHours": "number?",     // Actual time
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Collection Security Rules

### Basic Security Rules Template
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Assignments belong to specific users
    match /assignments/{assignmentId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    
    // Courses belong to specific users
    match /courses/{courseId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    
    // Groups can be read by members, written by owners
    match /groups/{groupId} {
      allow read: if request.auth != null && request.auth.uid in resource.data.members;
      allow write: if request.auth != null && request.auth.uid == resource.data.ownerId;
    }
    
    // Other collections follow similar patterns...
  }
}
```

## Implementation Status Legend
- ✅ **Implemented**: Currently working in production
- 🚧 **In Progress**: Currently being implemented
- 📋 **Planned**: Scheduled for future implementation
- ❌ **Not Started**: Not yet started

## Next Steps
1. **Phase 1**: Complete Assignments and Courses collections
2. **Phase 2**: Implement Calendar Events and User Availability
3. **Phase 3**: Add Intelligence and Analytics features
4. **Phase 4**: Optimize with caching and offline support
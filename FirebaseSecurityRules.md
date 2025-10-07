# Firebase Security Rules

## Firestore Security Rules

Copy and paste these rules into your Firebase Console > Firestore Database > Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Users collection - users can only access their own profile
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Assignments collection - users can only access their own assignments
    match /assignments/{assignmentId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
    
    // Courses collection - users can only access their own courses
    match /courses/{courseId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
    
    // Groups collection - members can read, owners can write
    match /groups/{groupId} {
      allow read: if request.auth != null && 
        request.auth.uid in resource.data.members;
      allow write: if request.auth != null && 
        request.auth.uid == resource.data.ownerId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.ownerId;
    }
    
    // Calendar Events collection (Phase 2)
    match /calendar_events/{eventId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == resource.data.userId ||
         request.auth.uid in resource.data.attendees);
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
    
    // User Availability collection (Phase 2)
    match /user_availability/{availabilityId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
    
    // Workload Analysis collection (Phase 2)
    match /workload_analysis/{analysisId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
    
    // Smart Recommendations collection (Phase 3)
    match /smart_recommendations/{recommendationId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
    
    // User Analytics collection (Phase 3)
    match /user_analytics/{analyticsId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
    
    // User Settings collection (Phase 3)
    match /user_settings/{settingsId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
    
    // Holidays collection (Phase 4) - read-only for all authenticated users
    match /holidays/{holidayId} {
      allow read: if request.auth != null;
      allow write: if false; // Only server-side writes allowed
    }
    
    // Academic Events collection (Phase 4)
    match /academic_events/{eventId} {
      allow read, write: if request.auth != null && 
        request.auth.uid == resource.data.userId;
      allow create: if request.auth != null && 
        request.auth.uid == request.resource.data.userId;
    }
  }
}
```

## Key Security Features

1. **Authentication Required**: All operations require a valid authenticated user
2. **User Isolation**: Users can only access their own data
3. **Group Access Control**: Group members can read, but only owners can modify
4. **Creation Validation**: Ensures user creating document is the owner
5. **Shared Resources**: Holiday data is read-only for all users
6. **Future-Proof**: Rules prepared for Phase 2-4 collections

## Testing Security Rules

Use the Firebase Emulator to test these rules:

```bash
firebase emulators:start --only firestore
```

## Deployment

Deploy these rules using Firebase CLI:

```bash
firebase deploy --only firestore:rules
```
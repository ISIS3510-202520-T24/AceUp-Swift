import Foundation
import UIKit

// MARK: - NSCache Wrapper con LRU para Subjects
class SubjectCache {
    
    static let shared = SubjectCache()
    
    private let cache = NSCache<NSString, CachedSubject>()
    private let semesterCache = NSCache<NSString, CachedSubjectList>()
    
    private let maxSubjectCount = 100
    private let maxMemoryBytes = 10 * 1024 * 1024  // 10 MB
    private let cacheTTL: TimeInterval = 5 * 60  // 5 minutes
    
    private init() {
        cache.countLimit = maxSubjectCount
        cache.totalCostLimit = maxMemoryBytes
        cache.name = "com.aceup.subjectCache"
        
        semesterCache.countLimit = 20
        semesterCache.totalCostLimit = 2 * 1024 * 1024  // 2 MB
        semesterCache.name = "com.aceup.semesterSubjectCache"
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCacheOnMemoryWarning()
        }
    }
    
    // MARK: - Get Subject (Individual)
    func getSubject(id: String) -> Subject? {
        guard let cached = cache.object(forKey: id as NSString) else {
            return nil
        }
        
        guard !cached.isExpired(ttl: cacheTTL) else {
            cache.removeObject(forKey: id as NSString)
            return nil
        }
        
        return cached.subject
    }
    
    // MARK: - Set Subject (Individual)
    func setSubject(_ subject: Subject) {
        let cost = estimateCost(for: subject)
        let cached = CachedSubject(subject: subject, timestamp: Date())
        cache.setObject(cached, forKey: subject.id as NSString, cost: cost)
    }
    
    // MARK: - Get Subjects (List by Semester)
    func getSubjects(forSemester semesterId: String) -> [Subject]? {
        guard let cached = semesterCache.object(forKey: semesterId as NSString) else {
            return nil
        }
        
        guard !cached.isExpired(ttl: cacheTTL) else {
            semesterCache.removeObject(forKey: semesterId as NSString)
            return nil
        }
        
        return cached.subjects
    }
    
    // MARK: - Set Subjects (List by Semester)
    func setSubjects(_ subjects: [Subject], forSemester semesterId: String) {
        let cost = subjects.reduce(0) { $0 + estimateCost(for: $1) }
        let cached = CachedSubjectList(subjects: subjects, timestamp: Date())
        semesterCache.setObject(cached, forKey: semesterId as NSString, cost: cost)
    }
    
    // MARK: - Invalidation
    func invalidateSubject(id: String) {
        cache.removeObject(forKey: id as NSString)
    }
    
    func invalidateSemester(id: String) {
        semesterCache.removeObject(forKey: id as NSString)
    }
    
    func clearAll() {
        cache.removeAllObjects()
        semesterCache.removeAllObjects()
    }
    
    // MARK: - Cost Estimation
    private func estimateCost(for subject: Subject) -> Int {
        let baseSize = MemoryLayout<Subject>.size
        let stringCost = subject.name.utf8.count + 
                        subject.code.utf8.count + 
                        (subject.instructor ?? "").utf8.count
        return baseSize + stringCost
    }
    
    private func clearCacheOnMemoryWarning() {
        cache.removeAllObjects()
        semesterCache.removeAllObjects()
    }
}

// MARK: - Cached Wrappers
class CachedSubject {
    let subject: Subject
    let timestamp: Date
    
    init(subject: Subject, timestamp: Date) {
        self.subject = subject
        self.timestamp = timestamp
    }
    
    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

class CachedSubjectList {
    let subjects: [Subject]
    let timestamp: Date
    
    init(subjects: [Subject], timestamp: Date) {
        self.subjects = subjects
        self.timestamp = timestamp
    }
    
    func isExpired(ttl: TimeInterval) -> Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

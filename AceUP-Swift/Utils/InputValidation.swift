//
//  InputValidation.swift
//  AceUP-Swift
//
//  Input validation and sanitization utilities for protecting against
//  SQL injection and enforcing character limits
//

import Foundation

/// Input validation and sanitization utilities
enum InputValidation {
    
    // MARK: - Character Limits
    
    /// Character limits for different input types
    enum CharacterLimit {
        static let name = 100
        static let email = 254  // RFC 5321 standard
        static let password = 128
        static let nickname = 50
        static let title = 200
        static let description = 1000
        static let courseName = 100
        static let groupName = 100
        static let university = 150
        static let studyProgram = 150
        static let searchQuery = 200
        static let tag = 30
        static let general = 500
    }
    
    // MARK: - SQL Injection Prevention
    
    /// Dangerous characters and patterns that could be used for SQL injection
    private static let sqlInjectionPatterns: [String] = [
        "'", "\"", ";", "--", "/*", "*/", "xp_", "sp_",
        "exec", "execute", "select", "insert", "update", "delete",
        "drop", "create", "alter", "union", "script", "<script",
        "javascript:", "onerror=", "onload="
    ]
    
    /// Sanitize input to prevent SQL injection and XSS attacks
    /// - Parameter input: The string to sanitize
    /// - Returns: Sanitized string safe for database operations
    static func sanitize(_ input: String) -> String {
        var sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove null bytes
        sanitized = sanitized.replacingOccurrences(of: "\0", with: "")
        
        // Escape dangerous characters (but allow normal apostrophes in names)
        // Note: Firebase/Firestore handles parameterization, but we add extra safety
        let dangerousChars: [Character: String] = [
            "\"": "",
            ";": "",
            "<": "",
            ">": "",
            "&": "and"
        ]
        
        for (char, replacement) in dangerousChars {
            sanitized = sanitized.replacingOccurrences(of: String(char), with: replacement)
        }
        
        // Remove SQL keywords when they appear in suspicious contexts
        let sqlKeywords = ["drop", "delete", "truncate", "exec", "execute", "script"]
        
        for keyword in sqlKeywords {
            // Only remove if the keyword appears in isolation (not part of a normal word)
            let pattern = "\\b\(keyword)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    range: NSRange(sanitized.startIndex..., in: sanitized),
                    withTemplate: ""
                )
            }
        }
        
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if input contains potentially dangerous patterns
    /// - Parameter input: The string to check
    /// - Returns: True if input appears safe, false if suspicious patterns detected
    static func isSafe(_ input: String) -> Bool {
        let lowercased = input.lowercased()
        
        // Check for suspicious patterns
        let suspiciousPatterns = [
            "';", "\";", "--", "/*", "*/",
            "drop table", "delete from", "insert into",
            "union select", "<script", "javascript:",
            "onerror=", "onload=", "eval("
        ]
        
        for pattern in suspiciousPatterns {
            if lowercased.contains(pattern) {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Character Limit Enforcement
    
    /// Enforce character limit on a string
    /// - Parameters:
    ///   - input: The string to limit
    ///   - limit: Maximum number of characters allowed
    /// - Returns: String truncated to the specified limit
    static func enforceLimit(_ input: String, limit: Int) -> String {
        if input.count > limit {
            return String(input.prefix(limit))
        }
        return input
    }
    
    /// Validate and sanitize input with character limit
    /// - Parameters:
    ///   - input: The string to validate and sanitize
    ///   - limit: Maximum number of characters allowed
    /// - Returns: Sanitized string within the character limit
    static func validateAndSanitize(_ input: String, limit: Int) -> String {
        let sanitized = sanitize(input)
        return enforceLimit(sanitized, limit: limit)
    }
    
    // MARK: - Specific Input Type Validators
    
    /// Sanitize and validate name input
    static func sanitizeName(_ name: String) -> String {
        return validateAndSanitize(name, limit: CharacterLimit.name)
    }
    
    /// Sanitize and validate email input
    static func sanitizeEmail(_ email: String) -> String {
        let sanitized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return enforceLimit(sanitized, limit: CharacterLimit.email)
    }
    
    /// Sanitize and validate password input
    static func sanitizePassword(_ password: String) -> String {
        // Don't apply aggressive sanitization to passwords, just enforce length
        return enforceLimit(password, limit: CharacterLimit.password)
    }
    
    /// Sanitize and validate nickname input
    static func sanitizeNickname(_ nickname: String) -> String {
        return validateAndSanitize(nickname, limit: CharacterLimit.nickname)
    }
    
    /// Sanitize and validate title input
    static func sanitizeTitle(_ title: String) -> String {
        return validateAndSanitize(title, limit: CharacterLimit.title)
    }
    
    /// Sanitize and validate description input
    static func sanitizeDescription(_ description: String) -> String {
        return validateAndSanitize(description, limit: CharacterLimit.description)
    }
    
    /// Sanitize and validate course name input
    static func sanitizeCourseName(_ courseName: String) -> String {
        return validateAndSanitize(courseName, limit: CharacterLimit.courseName)
    }
    
    /// Sanitize and validate group name input
    static func sanitizeGroupName(_ groupName: String) -> String {
        return validateAndSanitize(groupName, limit: CharacterLimit.groupName)
    }
    
    /// Sanitize and validate university input
    static func sanitizeUniversity(_ university: String) -> String {
        return validateAndSanitize(university, limit: CharacterLimit.university)
    }
    
    /// Sanitize and validate study program input
    static func sanitizeStudyProgram(_ program: String) -> String {
        return validateAndSanitize(program, limit: CharacterLimit.studyProgram)
    }
    
    /// Sanitize and validate search query input
    static func sanitizeSearchQuery(_ query: String) -> String {
        return validateAndSanitize(query, limit: CharacterLimit.searchQuery)
    }
    
    /// Sanitize and validate tag input
    static func sanitizeTag(_ tag: String) -> String {
        return validateAndSanitize(tag, limit: CharacterLimit.tag)
    }
}

// MARK: - String Extension for Convenience

extension String {
    /// Sanitize the string to prevent SQL injection
    var sanitized: String {
        return InputValidation.sanitize(self)
    }
    
    /// Check if the string is safe from SQL injection patterns
    var isSafeInput: Bool {
        return InputValidation.isSafe(self)
    }
    
    /// Enforce a character limit on the string
    func limited(to limit: Int) -> String {
        return InputValidation.enforceLimit(self, limit: limit)
    }
}

//
//  TextFieldModifiers.swift
//  AceUP-Swift
//
//  Custom ViewModifiers for TextField validation and sanitization
//

import SwiftUI

// MARK: - Character Limit Modifier

/// ViewModifier that enforces a character limit on text input
struct CharacterLimitModifier: ViewModifier {
    @Binding var text: String
    let limit: Int
    let sanitize: Bool
    
    func body(content: Content) -> some View {
        content
            .onChange(of: text) { oldValue, newValue in
                var processedText = newValue
                
                // Apply sanitization if requested
                if sanitize {
                    processedText = InputValidation.sanitize(processedText)
                }
                
                // Enforce character limit
                if processedText.count > limit {
                    text = String(processedText.prefix(limit))
                } else if processedText != newValue {
                    text = processedText
                }
            }
    }
}

// MARK: - Safe Input Modifier

/// ViewModifier that validates input for SQL injection patterns and shows warning
struct SafeInputModifier: ViewModifier {
    @Binding var text: String
    @State private var showWarning = false
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
                .onChange(of: text) { oldValue, newValue in
                    if !InputValidation.isSafe(newValue) {
                        // Auto-sanitize dangerous input
                        text = InputValidation.sanitize(newValue)
                        showWarning = true
                        
                        // Hide warning after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showWarning = false
                        }
                    }
                }
            
            if showWarning {
                Text("Invalid characters were removed")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showWarning)
    }
}

// MARK: - Combined Validation Modifier

/// ViewModifier that applies both character limit and sanitization
struct ValidatedInputModifier: ViewModifier {
    @Binding var text: String
    let limit: Int
    let showWarning: Bool
    
    func body(content: Content) -> some View {
        content
            .modifier(CharacterLimitModifier(text: $text, limit: limit, sanitize: true))
            .if(showWarning) { view in
                view.modifier(SafeInputModifier(text: $text))
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply character limit to text input
    /// - Parameters:
    ///   - text: Binding to the text value
    ///   - limit: Maximum number of characters
    ///   - sanitize: Whether to sanitize input (default: true)
    func characterLimit(_ text: Binding<String>, limit: Int, sanitize: Bool = true) -> some View {
        self.modifier(CharacterLimitModifier(text: text, limit: limit, sanitize: sanitize))
    }
    
    /// Validate input for SQL injection and other dangerous patterns
    /// - Parameter text: Binding to the text value
    func safeInput(_ text: Binding<String>) -> some View {
        self.modifier(SafeInputModifier(text: text))
    }
    
    /// Apply both character limit and input validation
    /// - Parameters:
    ///   - text: Binding to the text value
    ///   - limit: Maximum number of characters
    ///   - showWarning: Whether to show warning when dangerous input is detected (default: true)
    func validatedInput(_ text: Binding<String>, limit: Int, showWarning: Bool = true) -> some View {
        self.modifier(ValidatedInputModifier(text: text, limit: limit, showWarning: showWarning))
    }
    
    /// Conditional modifier
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Convenience Modifiers for Specific Input Types

extension View {
    /// Apply validation for name input
    func nameInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.name)
    }
    
    /// Apply validation for email input
    func emailInput(_ text: Binding<String>) -> some View {
        self.characterLimit(text, limit: InputValidation.CharacterLimit.email, sanitize: false)
    }
    
    /// Apply validation for password input (length only, no sanitization)
    func passwordInput(_ text: Binding<String>) -> some View {
        self.characterLimit(text, limit: InputValidation.CharacterLimit.password, sanitize: false)
    }
    
    /// Apply validation for nickname input
    func nicknameInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.nickname)
    }
    
    /// Apply validation for title input
    func titleInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.title)
    }
    
    /// Apply validation for description input
    func descriptionInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.description)
    }
    
    /// Apply validation for course name input
    func courseNameInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.courseName)
    }
    
    /// Apply validation for group name input
    func groupNameInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.groupName)
    }
    
    /// Apply validation for university input
    func universityInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.university)
    }
    
    /// Apply validation for study program input
    func studyProgramInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.studyProgram)
    }
    
    /// Apply validation for search query input
    func searchQueryInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.searchQuery)
    }
    
    /// Apply validation for tag input
    func tagInput(_ text: Binding<String>) -> some View {
        self.validatedInput(text, limit: InputValidation.CharacterLimit.tag)
    }
}

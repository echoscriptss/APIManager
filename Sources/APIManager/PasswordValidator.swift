//
//  PasswordValidator.swift
//  Despir
//
//  Created by Yogesh on 1/8/26.
//

// PasswordValidator.swift

import Foundation

public struct PasswordRules {
    public let minLength: Int

    public init(minLength: Int = 8) {
        self.minLength = minLength
    }
}

// PasswordValidationResult.swift

public enum PasswordValidationResult: Equatable {
    case valid
    case tooShort
    case missingUppercase
    case missingLowercase
    case missingNumber
    case passwordsDoNotMatch

    public var message: String {
        switch self {
        case .valid:
            return ""
        case .tooShort:
            return "Password must be at least 8 characters"
        case .missingUppercase:
            return "Password must contain at least one uppercase letter"
        case .missingLowercase:
            return "Password must contain at least one lowercase letter"
        case .missingNumber:
            return "Password must contain at least one number"
        case .passwordsDoNotMatch:
            return "Passwords do not match"
        }
    }
}


public struct PasswordValidator {
    private let rules: PasswordRules
    
    public init(rules: PasswordRules = PasswordRules()) {
        self.rules = rules
    }
    
    public func validate(password: String) -> PasswordValidationResult {
        if password.count < rules.minLength {
            return .tooShort
        }
        if password.range(of: "[A-Z]", options: .regularExpression) == nil {
            return .missingUppercase
        }
        if password.range(of: "[a-z]", options: .regularExpression) == nil {
            return .missingLowercase
        }
        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            return .missingNumber
        }
        return .valid
    }

    public func validate(password: String, confirmPassword: String) -> PasswordValidationResult {
        let passwordResult = validate(password: password)
        if passwordResult != .valid {
            return passwordResult
        }
        if password != confirmPassword {
            return .passwordsDoNotMatch
        }
        return .valid
    }
}

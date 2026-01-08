//
//  EmailValidator.swift
//  Despir
//
//  Created by Yogesh on 1/8/26.
//

import Foundation

public struct EmailValidator {

    public init() {}

    /// RFC 5322 compliant (practical version)
    public func isValid(email: String) -> Bool {
        let emailRegex =
        #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

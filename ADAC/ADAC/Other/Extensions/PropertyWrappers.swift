// Licensed under the Any Distance Source-Available License
//
//  PropertyWrappers.swift
//  ADAC
//
//  Created by Jarod Luebbert on 8/5/22.
//

import Foundation

@propertyWrapper
struct Clamped<Value: Comparable> {
    
    var value: Value
    let range: ClosedRange<Value>

    init(initialValue value: Value, _ range: ClosedRange<Value>) {
        precondition(range.contains(value))
        self.value = value
        self.range = range
    }

    var wrappedValue: Value {
        get { value }
        set { value = min(max(range.lowerBound, newValue), range.upperBound) }
    }
}

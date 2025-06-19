// Licensed under the Any Distance Source-Available License
//
//  PreferenceKeys.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/25/23.
//

import SwiftUI

struct CGFloatPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0.0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {}
}

struct CGRectPreferenceKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {}
}

struct CGSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize { .zero }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}


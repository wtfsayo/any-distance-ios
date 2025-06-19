// Licensed under the Any Distance Source-Available License
//
//  GeometryBinding.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/14/21.
//

import SwiftUI

public extension View {
    func bindGeometry(to binding: Binding<CGFloat>,
                      reader: @escaping (GeometryProxy) -> CGFloat) -> some View {
            self.background(GeometryBinding(reader: reader))
                .onPreferenceChange(GeometryPreference.self) {
                    binding.wrappedValue = $0
                }
        }
}

private struct GeometryBinding: View {
    let reader: (GeometryProxy) -> CGFloat

    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: GeometryPreference.self,
                value: self.reader(geo)
            )
        }
    }
}

private struct GeometryPreference: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

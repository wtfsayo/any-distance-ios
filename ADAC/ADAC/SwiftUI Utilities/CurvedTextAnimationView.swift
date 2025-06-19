// Licensed under the Any Distance Source-Available License
//
//  CurvedTextAnimationView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/23/23.
//

import SwiftUI

struct CurvedTextAnimationView: View {
    var text: String
    var texts: [(offset: Int, element: Character)] {
        return Array(text.enumerated())
    }
    var radius: Double

    @State var textWidths: [Int: Double] = [:]
    @State var animate: Bool = false
    @State var animationTimer: Timer?
    @State var textAnimationStates: [Int: Bool] = [:]

    struct WidthPreferenceKey: PreferenceKey {
        static var defaultValue: Double = 0
        static func reduce(value: inout Double, nextValue: () -> Double) {
            value = nextValue()
        }
    }

    struct Sizeable: View {
        var body: some View {
            GeometryReader { geometry in
                Color.clear
                    .preference(key: WidthPreferenceKey.self, value: geometry.size.width)
            }
        }
    }

    func angle(at index: Int) -> Angle {
        guard !texts.isEmpty else {
            return .zero
        }
        
        let clampedIndex = index.clamped(to: 0...(texts.count-1))
        guard let labelWidth = textWidths[clampedIndex] else { return .radians(0) }

        let circumference = radius * 2 * .pi

        let percent = labelWidth / circumference
        let labelAngle = percent * 2 * .pi

        let widthBeforeLabel = textWidths.filter{ $0.key < index }.map{ $0.value }.reduce(0, +)
        let percentBeforeLabel = widthBeforeLabel / circumference
        let angleBeforeLabel = percentBeforeLabel * 2 * .pi

        return .radians(angleBeforeLabel + labelAngle)
    }

    var body: some View {
        ZStack {
            ForEach(texts, id: \.offset) { index, letter in
                VStack {
                    let dampingFraction = 0.5 + (sin(Double(index) * 137.6) * 0.15)
                    Text(String(letter))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .background(Sizeable())
                        .onPreferenceChange(WidthPreferenceKey.self, perform: { width in
                            textWidths[index] = width
                        })
                        .rotation3DEffect(.degrees(textAnimationStates[index] ?? false ? 180 : 0), axis: .x)
                        .scaleEffect(y: textAnimationStates[index] ?? false ? -1 : 1)
                        .animation(.spring(response: 1.0,
                                           dampingFraction: 0.4,
                                           blendDuration: 0.3),
                                   value: textAnimationStates[index])
                    Spacer()
                }
                .rotationEffect(angle(at: index))
            }
        }
        .rotationEffect(.radians(angle(at: texts.count).radians * -0.5))
        .onAppear {
            for idx in 0..<texts.count {
                textAnimationStates[idx] = false
            }

            animationTimer?.invalidate()
            animationTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true, block: { _ in
                for idx in 0..<texts.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.05) {
                        textAnimationStates[idx] = !(textAnimationStates[idx] ?? false)
                    }
                }
            })
        }
    }
}

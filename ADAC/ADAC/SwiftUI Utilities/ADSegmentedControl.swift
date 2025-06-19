// Licensed under the Any Distance Source-Available License
//
//  ADSegmentedControl.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/9/23.
//

import SwiftUI
import SwiftUIX

struct ADSegmentedControl: View {
    var segments: [String]
    var fontSize: CGFloat = 15.0
    var showBg: Bool = true
    @Binding var selectedSegmentIdx: Int
    @Namespace private var segmentAnimation
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        HStack(spacing: -10) {
            ForEach(segments.enumerated().map { $0 }, id: \.element) { (idx, segment) in
                Button {
                    selectedSegmentIdx = idx
                    feedbackGenerator.impactOccurred()
                } label: {
                    Text(segment)
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundColor(idx == selectedSegmentIdx ? .black : .white)
                        .padding([.leading, .trailing], fontSize * 1.46)
                        .padding([.top, .bottom], fontSize * 0.86)
                        .background {
                            Color.black.opacity(0.01)
                                .padding([.top, .bottom], -20.0)
                        }
                }
                .background {
                    ZStack {
                        if idx == selectedSegmentIdx {
                            RoundedRectangle(cornerRadius: 30.0, style: .continuous)
                                .foregroundColor(.white)
                                .matchedGeometryEffect(id: "rect", in: segmentAnimation)
                        } else {
                            EmptyView()
                        }
                    }
                    .padding(0.24 * fontSize)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.5),
                           value: selectedSegmentIdx)
            }
        }
        .background {
            if showBg {
                DarkBlurView()
                    .brightness(0.1)
                    .cornerRadius(24.0, style: .continuous)
            } else {
                EmptyView()
            }
        }
    }
}

fileprivate struct PreviewWrapper: View {
    @State var selectedIdx: Int = 0

    var body: some View {
        ADSegmentedControl(segments: ["Segment 1", "Segment 2", "Segment 3"],
                           selectedSegmentIdx: $selectedIdx)
    }
}

#Preview {
    PreviewWrapper()
}

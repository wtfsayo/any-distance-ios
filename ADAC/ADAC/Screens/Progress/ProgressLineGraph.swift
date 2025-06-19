// Licensed under the Any Distance Source-Available License
//
//  ProgressLineGraph.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/8/23.
//

import SwiftUI
import SwiftUIX

fileprivate struct ProgressLine: Shape {
    var data: [Float]
    var dataMaxValue: Float
    var totalCount: Int

    func path(in rect: CGRect) -> Path {
        guard !data.isEmpty else {
            return Path()
        }
        
        let max = dataMaxValue * 1.1
        var path = Path()

        let points = data.enumerated().map { (i, datum) in
            let x = (rect.width * CGFloat(i) / CGFloat(totalCount-1)).clamped(to: 4.0...(rect.width-4.0))
            let y = (rect.height - (rect.height * CGFloat(datum / max))).clamped(to: 4.0...(rect.height-4.0))
            return CGPoint(x: x, y: y)
        }

        path.move(to: points[0])
        var p1 = points[0]
        var p2 = CGPoint.zero

        for i in 0..<(points.count-1) {
            p2 = points[i+1]
            let midPoint = CGPoint(x: (p1.x + p2.x)/2.0, y: (p1.y + p2.y)/2.0)
            path.addQuadCurve(to: midPoint, control: p1)
            p1 = p2
        }

        path.addLine(to: points.last!)

        return path
    }
}

struct ProgressLineGraph: View {
    var data: [Float]
    var dataMaxValue: Float
    var fullDataCount: Int
    var strokeStyle: StrokeStyle
    var color: Color
    var showVerticalLine: Bool
    var showDot: Bool
    var animateProgress: Bool
    @Binding var dataSwipeIdx: Int

    @State private var lineAnimationProgress: Float = 1.0
    @State private var dotOpacity: Double = 0.0

    var body: some View {
        ZStack {
            color
                .maxWidth(.infinity)
                .mask {
                    ProgressLine(data: data, dataMaxValue: dataMaxValue, totalCount: fullDataCount)
                        .stroke(style: strokeStyle)
                }
                .mask {
                    GeometryReader { geo in
                        HStack(spacing: 0.0) {
                            let width = (geo.size.width * (CGFloat(data.count-1) / CGFloat(fullDataCount-1)) * CGFloat(lineAnimationProgress)).clamped(to: 4.0...(geo.size.width-4.0))
                            Rectangle()
                                .frame(width: width)
                            Spacer()
                                .frame(minWidth: 0.0)
                        }
                    }
                }
                .if(showVerticalLine && data.count > 1) { view in
                    view
                        .background {
                            GeometryReader { geo in
                                HStack(spacing: 0.0) {
                                    let width: CGFloat = {
                                        if dataSwipeIdx != -1 {
                                            return (geo.size.width * (CGFloat(dataSwipeIdx) / CGFloat(fullDataCount-1))).clamped(to: 4.0...(geo.size.width-4.0))
                                        } else {
                                            return (geo.size.width * (CGFloat(data.count-1) / CGFloat(fullDataCount-1)) * CGFloat(lineAnimationProgress)).clamped(to: 4.0...(geo.size.width-4.0))
                                        }
                                    }()

                                    Spacer()
                                        .frame(width: width)
                                    ZStack {
                                        Color.black
                                        Rectangle()
                                            .foregroundColor(color)
                                            .opacity(0.4)
                                    }
                                    .frame(width: 2.0)
                                    .cornerRadius(2.0)
                                    Spacer()
                                        .frame(minWidth: 0.0)
                                }
                                .offset(x: -1.5)
                                .animation(dataSwipeIdx == -1 ? .timingCurve(0.42, 0.27, 0.34, 0.96, duration: 0.2) : .none,
                                           value: dataSwipeIdx)
                            }
                        }
                }
                .if(showDot) { view in
                    view
                        .overlay {
                            GeometryReader { geo in
                                let x = (geo.size.width * CGFloat(data.count-1) / CGFloat(fullDataCount-1)).clamped(to: 4.0...(geo.size.width-4.0))
                                let y = (geo.size.height - (geo.size.height * CGFloat((data.last ?? 0.0) / (dataMaxValue * 1.1)))).clamped(to: 4.0...(geo.size.height-4.0))

                                ZStack {
                                    TimelineView(.animation) { timeline in
                                        Canvas { context, size in
                                            let duration: CGFloat = 1.4
                                            let time = timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: duration) / duration
                                            let diameter = 12.0 + (20.0 * time)
                                            let rect = CGRect(x: 21.0 - (diameter / 2),
                                                              y: 21.0 - (diameter / 2),
                                                              width: diameter,
                                                              height: diameter)
                                            let shape = Circle().path(in: rect)
                                            let color = color.opacity(1.0 - time)
                                            context.fill(shape,
                                                         with: .color(color))
                                        }
                                    }
                                    .frame(width: 42.0, height: 42.0)

                                    Circle()
                                        .fill(color)
                                        .width(12.0)
                                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
                                }
                                .scaleEffect(x: dotOpacity, y: dotOpacity)
                                .position(x: x, y: y)
                                .opacity(dotOpacity)
                            }
                        }
                }
                .opacity(Double(lineAnimationProgress))
                .onAppear {
                    if !animateProgress {
                        lineAnimationProgress = 1.0
                        dotOpacity = 1.0
                        return
                    }

                    lineAnimationProgress = 0.0
                    let duration = (0.3 + ((CGFloat(data.count-1) / CGFloat(fullDataCount-1)) * 0.9)).clamped(to: 0.0...0.9)
                    withAnimation(.timingCurve(0.42, 0.27, 0.34, 0.96, duration: duration)) {
                        lineAnimationProgress = 1.0
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + duration - 0.13) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            self.dotOpacity = 1.0
                        }
                    }
                }
        }
    }
}

struct ProgressLineGraphXLabels: View {
    var labelStrings: [(idx: Int, string: String)] = []
    var fullDataCount: Int
    var lrPadding: CGFloat

    var body: some View {
        Color.clear
            .overlay {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        ForEach(labelStrings, id: \.idx) { (idx, string) in
                            let xPos: CGFloat = (lrPadding + ((geo.size.width - (lrPadding * 2.0)) * CGFloat(idx) / CGFloat(fullDataCount - 1))).clamped(to: (lrPadding+4.0)...(geo.size.width-lrPadding-4.0))
                            HStack {
                                Text(string)
                                    .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .opacity(0.6)
                                    .frame(width: 50.0)
                                    .offset(x: xPos - 25.0)
                                Spacer()
                            }
                        }
                    }
                }
            }
    }
}

struct ProgressLineGraphSwipeOverlay: View {
    var field: PartialKeyPath<Activity>
    var data: [Float]
    var prevPeriodData: [Float]
    var dataFormat: (Float) -> String
    var startDate: Date
    var endDate: Date
    var prevPeriodStartDate: Date
    var prevPeriodEndDate: Date
    var alternatePrevPeriodLabel: String?
    @Binding var dataSwipeIdx: Int
    @Binding var showingOverlay: Bool

    @State private var dragLocation: CGPoint = .zero
    @State private var touchingDown: Bool = false
    @State private var longPressTimer: Timer?

    private let longPressDuration: TimeInterval = 0.1
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    var percentChangeLabel: some View {
        ZStack {
            let percent = ((data[dataSwipeIdx.clamped(to: 0...(data.count-1))] / (prevPeriodData[dataSwipeIdx.clamped(to: 0...(prevPeriodData.count-1))])
                .clamped(to: 0.01...Float.greatestFiniteMagnitude)) - 1.0)
                .clamped(to: -10.0...100.0)

            let glyphName: SFSymbolName = {
                switch abs(percent) {
                case 0.0:
                    return .minusCircleFill
                default:
                    return percent > 0.0 ? .arrowUpRightCircleFill : .arrowDownRightCircleFill
                }
            }()

            let percentString: String = {
                switch abs(percent) {
                case 100.0:
                    return "∞"
                case 0.0:
                    return "0"
                default:
                    return String(Int((abs(percent) * 100).rounded()))
                }
            }()

            let color = ActivityProgressGraphModel.color(for: percent, field: field)

            HStack(spacing: 3.0) {
                Image(systemName: glyphName)
                    .font(.system(size: 12.0, weight: .medium))
                HStack(spacing: 0.0) {
                    if percentString == "∞" {
                        Text(percentString)
                            .font(.system(size: 12.0, weight: .medium))
                    } else {
                        Text(percentString)
                            .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                    }
                    Text("%")
                        .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                }
            }
            .foregroundColor(color)
        }
    }

    var body: some View {
        Color.clear
            .overlay {
                GeometryReader { geo in
                    VStack {
                        Spacer()

                        if showingOverlay {
                            let overlayWidth: CGFloat = dataSwipeIdx >= data.count ? 110.0 : 155.0
                            let xOffset = (CGFloat(dataSwipeIdx) * (geo.size.width / CGFloat(max(data.count, prevPeriodData.count) - 1)) - (overlayWidth / 2.0))
                                .clamped(to: 0...(geo.size.width - overlayWidth))
                            HStack(spacing: 0.0) {
                                VStack(alignment: .leading, spacing: 8.0) {
                                    if dataSwipeIdx < data.count {
                                        VStack(alignment: .leading, spacing: 1.0) {
                                            HStack {
                                                Text(dataFormat(data[dataSwipeIdx.clamped(to: 0...(data.count-1))]))
                                                    .font(.system(size: 13.0, weight: .medium, design: .monospaced))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.5)
                                                Spacer()
                                                percentChangeLabel
                                            }
                                            Text(Calendar.current.date(byAdding: .day, value: dataSwipeIdx, to: startDate)!.formatted(withFormat: "MMM d YYYY"))
                                                .font(.system(size: 10.0, design: .monospaced))
                                                .opacity(0.5)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 1.0) {
                                        let idx = dataSwipeIdx.clamped(to: 0...(prevPeriodData.count-1))
                                        Text(dataFormat(prevPeriodData[idx]))
                                            .font(.system(size: 13.0, weight: .medium, design: .monospaced))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5)
                                        if let alternatePrevPeriodLabel = alternatePrevPeriodLabel {
                                            Text(alternatePrevPeriodLabel)
                                                .font(.system(size: 10.0, design: .monospaced))
                                                .opacity(0.5)
                                        } else {
                                            Text(Calendar.current.date(byAdding: .day, value: idx, to: prevPeriodStartDate)!.formatted(withFormat: "MMM d YYYY"))
                                                .font(.system(size: 10.0, design: .monospaced))
                                                .opacity(0.5)
                                        }
                                    }
                                }

                                if dataSwipeIdx >= data.count {
                                    Spacer()
                                }
                            }
                            .padding(8.0)
                            .frame(width: overlayWidth)
                            .background {
                                DarkBlurView()
                                    .cornerRadius(11.0)
                                    .brightness(0.1)
                            }
                            .modifier(BlurOpacityTransition(speed: 2.5,
                                                            anchor: UnitPoint(x: (xOffset + (overlayWidth / 2.0)) / overlayWidth, y: -2.5)))
                            .offset(x: xOffset,
                                    y: (-1.0 * geo.size.height) - 8.0)
                        }
                    }
                }
            }
            .overlay {
                TouchEventView { location, view in
                    guard let location = location else {
                        return
                    }

                    touchingDown = true
                    longPressTimer?.invalidate()

                    longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDuration,
                                                          repeats: false) { _ in
                        guard touchingDown else {
                            return
                        }

                        longPressTimer?.invalidate()
                        longPressTimer = nil
                        view.findContainingScrollView()?.isScrollEnabled = false

                        dataSwipeIdx = Int(location.x / (view.bounds.width / CGFloat(max(data.count, prevPeriodData.count))))
                            .clamped(to: 0...max(prevPeriodData.count-1, data.count-1))

                        showingOverlay = true
                        dragLocation = location
                    }
                } touchMoved: { location, view in
                    guard let location = location, showingOverlay else {
                        return
                    }

                    let prevIdx = dataSwipeIdx
                    dataSwipeIdx = Int(location.x / (view.bounds.width / CGFloat(prevPeriodData.count)))
                        .clamped(to: 0...max(prevPeriodData.count-1, data.count-1))

                    if dataSwipeIdx != prevIdx {
                        feedbackGenerator.impactOccurred()
                    }
                    dragLocation = location
                } touchCancelled: { location, view in
                    showingOverlay = false
                    view.findContainingScrollView()?.isScrollEnabled = true
                    touchingDown = false
                    dataSwipeIdx = -1
                } touchEnded: { location, view in
                    showingOverlay = false
                    view.findContainingScrollView()?.isScrollEnabled = true
                    touchingDown = false
                    dataSwipeIdx = -1
                }
            }
    }
}

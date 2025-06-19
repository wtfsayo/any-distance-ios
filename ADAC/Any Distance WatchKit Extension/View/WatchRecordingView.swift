// Licensed under the Any Distance Source-Available License
//
//  WatchRecordingView.swift
//  Any Distance WatchKit Extension
//
//  Created by Daniel Kuntz on 8/17/22.
//

import SwiftUI
import MapKit
import UIKit
import Combine
import CoreLocation

enum RectCorner: String, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

class Corner: Identifiable {
    var cornerType: RectCorner

    init(cornerType: RectCorner) {
        self.cornerType = cornerType
    }
}

fileprivate struct BackgroundMap: View {
    @ObservedObject var model: WatchRecordingViewModel
    @State var mapRect: MKMapRect = MKCoordinateRegion(center: .init(latitude: 33.75, longitude: -84.38),
                                                       latitudinalMeters: 10000,
                                                       longitudinalMeters: 10000).mapRect()
    private let annotationItems = RectCorner.allCases.map { Corner(cornerType: $0) }

    fileprivate struct CircleAnnotation: View {
        var body: some View {
            Circle()
                .fill(.orange)
                .frame(width: 5, height: 5)
                .opacity(0)
        }
    }

    func annotationItem(forCorner corner: Corner) -> MapAnnotation<CircleAnnotation> {
        switch corner.cornerType {
        case .topLeft:
            return MapAnnotation(coordinate: mapRect.origin.coordinate) {
                CircleAnnotation()
            }
        case .topRight:
            let coordinate = MKMapPoint(x: mapRect.origin.x + mapRect.width,
                                        y: mapRect.origin.y).coordinate
            return MapAnnotation(coordinate: coordinate) {
                CircleAnnotation()
            }
        case .bottomLeft:
            let coordinate = MKMapPoint(x: mapRect.origin.x,
                                        y: mapRect.origin.y + mapRect.height).coordinate
            return MapAnnotation(coordinate: coordinate) {
                CircleAnnotation()
            }
        case .bottomRight:
            let coordinate = MKMapPoint(x: mapRect.origin.x + mapRect.width,
                                        y: mapRect.origin.y + mapRect.height).coordinate
            return MapAnnotation(coordinate: coordinate) {
                CircleAnnotation()
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            Map(mapRect: $mapRect,
                interactionModes: .pan,
                showsUserLocation: false,
                userTrackingMode: .constant(.none),
                annotationItems: annotationItems) { corner in
                return annotationItem(forCorner: corner)
            }
                .allowsHitTesting(false)
                .ignoresSafeArea()
                .saturation(0.0)
                .contrast(1.45)
                .brightness(0.08)
                .onChange(of: model.recorder.currentLocation) { newValue in
                    let newMapRect = model.recorder
                                          .regionForCurrentRoute()?
                                          .mapRect() ?? mapRect

                    if !MKMapRectEqualToRect(mapRect, newMapRect) {
                        mapRect = newMapRect
                    }
                }
                .onChange(of: mapRect) { newValue in
                    model.visibleMapRect = newValue.expandedMapRectForScreen(withSafeAreaInsets: geo.safeAreaInsets)
                }
        }
    }
}

fileprivate struct RouteLine: Shape {
    var locations: [CLLocation]
    var mapRect: MKMapRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let maxCoordianteCount = 120
        let s = max(locations.count / maxCoordianteCount, 1)

        for i in stride(from: 0, to: locations.count, by: s) {
            let coord = locations[i].coordinate
            let mapPoint = MKMapPoint(coord)
            let xP = (mapPoint.x - mapRect.origin.x) / mapRect.width
            let yP = (mapPoint.y - mapRect.origin.y) / mapRect.height
            let screenX = (xP * rect.width) + rect.origin.x
            let screenY = (yP * rect.height) + rect.origin.y
            if path.currentPoint == nil {
                path.move(to: CGPoint(x: screenX, y: screenY))
            } else {
                path.addLine(to: CGPoint(x: screenX, y: screenY))
            }
        }

        return path
    }
}

fileprivate struct UserLocationView: View {
    @ObservedObject var model: WatchRecordingViewModel
    @State private var grow: Bool = false
    @State private var offset: CGPoint = .zero

    private func updateOffset() {
        if let mapRect = model.visibleMapRect,
           let location = model.recorder.currentLocation {

            let mapPoint = MKMapPoint(location.coordinate)
            let xP = (mapPoint.x - mapRect.origin.x) / mapRect.size.width
            let yP = (mapPoint.y - mapRect.origin.y) / mapRect.size.height

            offset = CGPoint(x: xP * WKInterfaceDevice.current().screenBounds.width,
                             y: yP * WKInterfaceDevice.current().screenBounds.height)
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.adOrangeLighter))
                .frame(width: 12)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
                .background {
                    Circle()
                        .fill(Color(UIColor.adOrangeLighter))
                        .frame(width: 12.0)
                        .scaleEffect(grow ? 3.5 : 1.0)
                        .opacity(grow ? 0.0 : 1.0)
                        .animation(.linear(duration: 1.4).repeatForever(autoreverses: false),
                                   value: grow)
                }
                .position(x: offset.x,
                          y: offset.y)
                .opacity(model.recorder.currentLocation == nil ? 0 : 1)
                .onAppear {
                    grow = true
                }
                .onChange(of: model.visibleMapRect) { _ in
                    updateOffset()
                }
                .onChange(of: model.recorder.currentLocation) { _ in
                    updateOffset()
                }
        }
        .ignoresSafeArea()
    }
}

fileprivate struct CountdownView: View {
    @State private var animationStep: CGFloat = 4
    @State private var animationTimer: Timer?
    @State private var isFinished: Bool = false
    var finishedAction: () -> Void

    func hStackXOffset() -> CGFloat {
        let clampedStep = animationStep.clamped(to: 0...3)
        if clampedStep > 0 {
            return 60 * (clampedStep - 1) - 10
        } else {
            return -90
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [.init(white: 0.15), .init(white: 0.25)],
                                     startPoint: .top,
                                     endPoint: .bottom))

            HStack(alignment: .center, spacing: 0) {
                Text("3")
                    .font(.system(size: 79, weight: .medium, design: .default))
                    .frame(width: 60)
                    .opacity(animationStep >= 3 ? 1 : 0.6)
                    .scaleEffect(animationStep >= 3 ? 1 : 0.6)
                Text("2")
                    .font(.system(size: 79, weight: .medium, design: .default))
                    .frame(width: 60)
                    .opacity(animationStep == 2 ? 1 : 0.6)
                    .scaleEffect(animationStep == 2 ? 1 : 0.6)
                Text("1")
                    .font(.system(size: 79, weight: .medium, design: .default))
                    .frame(width: 60)
                    .offset(x: -3)
                    .opacity(animationStep == 1 ? 1 : 0.6)
                    .scaleEffect(animationStep == 1 ? 1 : 0.6)
                Text("GO")
                    .font(.system(size: 55, weight: .semibold, design: .default))
                    .frame(width: 100)
                    .opacity(animationStep == 0 ? 1 : 0.6)
                    .scaleEffect(animationStep == 0 ? 1 : 0.6)
            }
            .offset(x: hStackXOffset(), y: -2)
        }
        .frame(width: 90, height: 135)
        .mask {
            RoundedRectangle(cornerRadius: 45)
                .frame(width: 90, height: 135)
        }
        .opacity(isFinished ? 0 : 1)
        .scaleEffect(isFinished ? 1.2 : 1)
        .opacity(animationStep < 4 ? 1 : 0)
        .scaleEffect(animationStep < 4 ? 1 : 0.8)
        .onTapGesture {
            animationTimer?.invalidate()
            withAnimation(.easeIn(duration: 0.15)) {
                isFinished = true
            }
            finishedAction()
        }
        .onAppear {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true, block: { _ in
                if animationStep == 0 {
                    withAnimation(.easeIn(duration: 0.15)) {
                        isFinished = true
                    }
                    finishedAction()
                    animationTimer?.invalidate()
                }

                withAnimation(.easeInOut(duration: animationStep == 4 ? 0.3 : 0.4)) {
                    animationStep -= 1
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if animationStep < 4 && animationStep > 0 {
                        WKInterfaceDevice.current().play(.click)
                    } else if animationStep == 0 {
                        WKInterfaceDevice.current().play(.click)
                    }
                }
            })
        }
    }
}

fileprivate struct StateLabel: View {
    var state: WatchActivityRecorder.RecordingState

    struct RecordingCircle: View {
        @State var grow: Bool = false

        var body: some View {
            Circle()
                .foregroundColor(Color(hexadecimal: "30D158"))
                .frame(width: 10)
                .overlay {
                    Circle()
                        .foregroundColor(.black)
                        .frame(width: 4)
                }
                .background {
                    Circle()
                        .foregroundColor(Color(hexadecimal: "30D158"))
                        .scaleEffect(grow ? 2.0 : 1)
                        .opacity(grow ? 0 : 1)
                        .animation(.linear(duration: 1.3).repeatForever(autoreverses: false),
                                   value: grow)
                }
                .onAppear {
                    grow = true
                }
        }
    }

    struct BlurModifier: ViewModifier {
        var radius: CGFloat

        func body(content: Content) -> some View {
            content.blur(radius: radius)
        }
    }

    var body: some View {
        HStack {
            switch state {
            case .ready, .locationPermissionNeeded:
                EmptyView()
            case .recording:
                RecordingCircle()
            case .paused:
                Circle()
                    .foregroundColor(Color(UIColor.adOrangeLighter))
                    .frame(width: 14)
                    .overlay {
                        Image(systemName: "pause.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.black)
                            .frame(width: 6)
                    }
            case .saving:
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14)
            case .saved:
                Circle()
                    .foregroundColor(Color(hexadecimal: "30D158"))
                    .frame(width: 14)
                    .overlay {
                        Image(systemName: "checkmark")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.black)
                            .font(.system(size: 10, weight: .black, design: .default))
                            .frame(width: 8)
                    }
            case .discarded, .couldNotSave:
                Image(systemName: "info.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(Color(UIColor.adOrangeLighter))
                    .frame(width: 14)
            }
            Text(state.displayName)
                .foregroundColor(Color(state.displayColor))
                .font(.system(size: 15, weight: .medium, design: .default))
                .shadow(color: .black, radius: 8)
        }
        .offset(y: 1)
        .id(state.displayName)
        .transition(.scale(scale: 0.8)
                    .combined(with: .opacity)
                    .combined(with: .modifier(active: BlurModifier(radius: 8),
                                              identity: BlurModifier(radius: 0)))
                    .animation(.easeInOut(duration: 0.35)))
    }
}

fileprivate struct SlideToStop: View {
    @Binding var touchingDown: Bool
    var onSuccessfulSlide: () -> Void

    @State private var xTranslation: CGFloat = 0.0
    @State private var gestureStartTime: Date?
    @State private var textAnimate: Bool = false

    var body: some View {
        GeometryReader { geo in
            let dragGesture = DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { gesture in
                    touchingDown = true
                    xTranslation = gesture.translation.width.clamped(to: 0...(geo.size.width * 0.7 - 32))
                    gestureStartTime = Date()
                }
                .onEnded { _ in
                    if xTranslation >= (geo.size.width * 0.7 - 32) {
                        onSuccessfulSlide()
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            xTranslation = 0.0
                        }

                        if let startTime = gestureStartTime,
                           Date().timeIntervalSince(startTime) < 1 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if startTime == gestureStartTime {
                                    touchingDown = false
                                }
                            }
                        } else {
                            touchingDown = false
                        }
                    }
                }

            ZStack {
                ZStack {
                    VStack(spacing: 12) {
                        Spacer()
                        RoundedRectangle(cornerRadius: geo.size.width * 0.3)
                            .fill(Color.adOrangeLighter)
                            .frame(height: geo.size.width * 0.3)
                            .overlay {
                                LinearGradient(colors: [.black, .black, .black, Color(uiColor: .adOrangeLighter.lighter(by: 20)!), .black, .black, .black],
                                               startPoint: .leading,
                                               endPoint: .trailing)
                                .frame(width: geo.size.width * 2)
                                .offset(x: textAnimate ? 0.5 * geo.size.width : -0.5 * geo.size.width)
                                .animation(.linear(duration: 1.3).repeatForever(autoreverses: false), value: textAnimate)
                                .mask {
                                    Text("Slide to stop")
                                        .foregroundColor(.black)
                                        .font(.system(size: geo.size.width * 0.072, weight: .semibold, design: .default))
                                        .offset(x: geo.size.width * 0.12)
                                }
                                .onAppear {
                                    textAnimate = true
                                }
                            }
                            .opacity(touchingDown ? 1 : 0)
                            .animation(.easeInOut(duration: touchingDown ? 0.3 : 0.15).delay(touchingDown ? 0.05 : 0), value: touchingDown)
                        Text("placeholder")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .opacity(0)
                        Spacer()
                    }
                }

                HStack {
                    VStack(spacing: 12) {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(.white)
                                .overlay {
                                    Image(systemName: "stop.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .scaleEffect(0.35)
                                        .foregroundColor(.black)
                                }
                        }
                        .opacity(touchingDown ? 0.6 : 1)
                        .scaleEffect(touchingDown ? 0.9 : 1)
                        .animation(.easeInOut(duration: 0.15), value: touchingDown)
                        .background {
                            Circle()
                                .fill(Color.adOrangeLighter)
                                .opacity(touchingDown ? 1 : 0)
                                .animation(.easeInOut(duration: touchingDown ? 0.3 : 0.15).delay(touchingDown ? 0.05 : 0), value: touchingDown)
                        }
                        .offset(x: xTranslation)
                        .gesture(dragGesture)
                        .frame(width: geo.size.width * 0.3, height: geo.size.width * 0.3)

                        Text("End")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .opacity(0.8)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .padding([.leading, .trailing], 16)
        }
    }
}

fileprivate struct Controls: View {
    @ObservedObject var model: WatchRecordingViewModel

    @State var stopTouchingDown: Bool = false
    @State private var showingDiscardAlert: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 12) {
                    Spacer()
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        Task {
                            try await model.recorder.pause()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.adOrangeLighter)
                            Image(systemName: "pause.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: geo.size.width * 0.18)
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(TransparentButtonStyle())
                    .frame(width: geo.size.width * 0.5, height: geo.size.width * 0.5)
                    Text("Pause")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .opacity(0.8)
                    Spacer()
                }
                .opacity(model.recorder.state == .recording ? 1 : 0)
                .scaleEffect(model.recorder.state == .recording ? 1 : 0.75)
                .blur(radius: model.recorder.state == .recording ? 0 : 20)
                .animation(.easeInOut(duration: 0.15).delay(model.recorder.state == .paused ? 0 : 0.1),
                           value: model.recorder.state)

                VStack {
                    Spacer()
                    HStack {
                        Button {
                            showingDiscardAlert = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 35, height: 35)

                                Image(systemName: "trash")
                                    .foregroundColor(Color.red)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .buttonStyle(TransparentButtonStyle())
                        .padding(16)
                        .opacity(model.recorder.state == .paused ? 1 : 0)
                        .opacity(stopTouchingDown ? 0 : 1)
                        .scaleEffect(model.recorder.state == .paused ? 1 : 0.75)
                        .blur(radius: model.recorder.state == .paused ? 0 : 20)
                        .scaleEffect(stopTouchingDown ? 0.75 : 1)
                        .animation(.easeInOut(duration: 0.15).delay(model.recorder.state == .paused ? 0.1 : 0),
                                   value: model.recorder.state)
                        .animation(.easeInOut(duration: 0.15), value: stopTouchingDown)
                        Spacer()
                    }
                }
                .ignoresSafeArea()

                SlideToStop(touchingDown: $stopTouchingDown) {
                    WKInterfaceDevice.current().play(.click)
                    Task {
                        await model.recorder.finish()
                    }
                }
                .opacity(model.recorder.state == .paused ? 1 : 0)
                .scaleEffect(model.recorder.state == .paused ? 1 : 0.75)
                .blur(radius: model.recorder.state == .paused ? 0 : 20)
                .animation(.easeInOut(duration: 0.15).delay(model.recorder.state == .paused ? 0.05 : 0.05),
                           value: model.recorder.state)
                .offset(y: -12)

                HStack {
                    Spacer()

                    VStack(spacing: 12) {
                        Spacer()
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            Task {
                                try await model.recorder.resume()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.adOrangeLighter)
                                Image(systemName: "play.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: geo.size.width * 0.16)
                                    .offset(x: 3)
                                    .foregroundColor(.black)
                            }
                        }
                        .buttonStyle(TransparentButtonStyle())
                        .frame(width: geo.size.width * 0.425, height: geo.size.width * 0.425)
                        Text("Resume")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .opacity(0.8)
                        Spacer()
                    }
                    .opacity(model.recorder.state == .paused ? 1 : 0)
                    .opacity(stopTouchingDown ? 0 : 1)
                    .scaleEffect(model.recorder.state == .paused ? 1 : 0.75)
                    .blur(radius: model.recorder.state == .paused ? 0 : 20)
                    .scaleEffect(stopTouchingDown ? 0.75 : 1)
                    .animation(.easeInOut(duration: 0.15).delay(model.recorder.state == .paused ? 0.1 : 0),
                               value: model.recorder.state)
                    .animation(.easeInOut(duration: 0.15), value: stopTouchingDown)
                }
                .padding([.leading, .trailing], 16)
                .offset(y: -12)
            }
        }
        .alert("Are you sure you want to discard this activity?", isPresented: $showingDiscardAlert) {
            Button("Discard activity", role: .destructive) {
                model.recorder.stopAndDiscardActivity()
            }
        }
    }
}

fileprivate struct GoalProgressBar: View {
    @ObservedObject var model: WatchRecordingViewModel

    private var goalColor: Color {
        return Color(model.recorder.goal.type.color)
    }

    private var lighterGoalColor: Color {
        return Color(model.recorder.goal.type.color.darker(by: 20) ?? model.recorder.goal.type.color)
    }

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(white: 0.3))
                .frame(height: 4)
                .frame(maxWidth: .infinity)
                .overlay {
                    GeometryReader { geo in
                        ZStack {
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(colors: [lighterGoalColor, goalColor],
                                                       startPoint: .leading,
                                                       endPoint: .trailing)
                                    )
                                Spacer()
                                    .frame(width: CGFloat(1 - model.recorder.goalProgress) * geo.size.width)
                            }
                            .frame(height: 4)
                            .offset(y: -3)
                            .zIndex(-1)

                            Circle()
                                .fill(goalColor)
                                .frame(width: 10, height: 10)
                                .overlay {
                                    Circle()
                                        .fill(goalColor)
                                        .frame(width: 16, height: 16)
                                        .blur(radius: 8)
                                        .opacity(0.9)
                                }
                                .offset(x: CGFloat(model.recorder.goalProgress - 0.5) * geo.size.width,
                                        y: -3)
                        }
                    }
                }

            Text(model.recorder.goal.shortFormattedTargetWithUnit)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(Color(white: 0.8))
        }
        .padding(.leading, 4)
        .animation(.easeInOut(duration: 0.15), value: model.recorder.goalProgress)
    }
}

fileprivate struct StatText: View {
    enum StatValueFormatting {
        case decimal
        case decimalOnePlace
        case timestamp
        case timestampLimitedToOneHour
        case integer
    }

    var label: String
    var value: Double
    var formatting: StatValueFormatting
    var unit: String = ""
    var isBold: Bool = false
    var bigFontSize: CGFloat = 38
    var smallFontSize: CGFloat = 13.5
    var showUnitInSuperscript: Bool = true
    var boldColor: UIColor = .adYellow

    private var valueString: String {
        switch formatting {
        case .decimal:
            return "\(value.rounded(toPlaces: 2))".zeroPadded(to: 4, front: false)
        case .decimalOnePlace:
            return "\(value.rounded(toPlaces: 1))".zeroPadded(to: 3, front: false)
        case .timestamp:
            return TimeInterval(value).timeFormatted()
        case .timestampLimitedToOneHour:
            return TimeInterval(value.clamped(to: 0...3599)).timeFormatted()
        case .integer:
            return "\(Int(value.rounded()))".zeroPadded(to: 3, front: true)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: bigFontSize / 10) {
                    Text(valueString)
                        .font(.system(size: bigFontSize,
                                      weight: isBold ? .semibold : .regular,
                                      design: .default).monospacedDigit())
                        .frame(height: bigFontSize * 0.8)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.bottom, bigFontSize * 0.08)
                    if showUnitInSuperscript {
                        Text(unit)
                            .font(.system(size: smallFontSize * 0.9,
                                          weight: isBold ? .bold : .semibold,
                                          design: .monospaced))
                            .foregroundColor(isBold ? Color(boldColor) : Color(white: 0.8))
                            .fixedSize(horizontal: true, vertical: false)
                            .offset(y: 0)
                    }
                }

                let labelText = (!showUnitInSuperscript && !unit.isEmpty) ? "\(label) - \(unit)" : label
                Text(labelText)
                    .font(.system(size: smallFontSize, weight: .semibold, design: .default))
                    .foregroundColor(isBold ? Color(boldColor) : Color(white: 0.8))
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(height: smallFontSize)
            }
            .foregroundColor(isBold ? Color(boldColor) : .white)
            Spacer()
        }
    }
}

fileprivate struct Stats: View {
    enum StatType {
        case time
        case distance
        case paceOrSpeed
        case activeCalories
        case elevation
        case heartRate

        var color: UIColor {
            switch self {
            case .time:
                return RecordingGoalType.time.color
            case .distance:
                return RecordingGoalType.distance.color
            case .activeCalories:
                return RecordingGoalType.calories.color
            case .paceOrSpeed, .heartRate, .elevation:
                return .white
            }
        }
    }

    @ObservedObject var model: WatchRecordingViewModel

    var durationLabelString: String {
        switch model.recorder.duration {
        case 0..<60:
            return "SEC"
        case 60..<3600:
            return "MIN"
        default:
            return "HRS"
        }
    }

    func statText(for statType: StatType, big: Bool = false) -> some View {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width

        let bigFontSize: CGFloat = big ? (screenWidth * 0.25) : (screenWidth * 0.15)
        let smallFontSize: CGFloat = big ? (screenWidth * 0.0875) : (screenWidth * 0.07)

        var boldColor: UIColor {
            if model.recorder.goal.type == .open && big {
                return .white
            }

            return statType.color
        }

        switch statType {
        case .time:
            return StatText(label: durationLabelString,
                            value: model.recorder.duration,
                            formatting: .timestamp,
                            isBold: big,
                            bigFontSize: bigFontSize,
                            smallFontSize: smallFontSize,
                            showUnitInSuperscript: big,
                            boldColor: boldColor)
        case .distance:
            return StatText(label: model.recorder.unit.abbreviation.uppercased(),
                            value: model.recorder.distanceInUnit,
                            formatting: .decimal,
                            isBold: big,
                            bigFontSize: bigFontSize,
                            smallFontSize: smallFontSize,
                            showUnitInSuperscript: big,
                            boldColor: boldColor)
        case .paceOrSpeed:
            if model.recorder.activityType.shouldShowSpeedInsteadOfPace {
                return StatText(label: "AVG SPEED",
                                value: model.recorder.avgSpeed,
                                formatting: .decimalOnePlace,
                                unit: model.recorder.unit.speedAbbreviation.uppercased(),
                                isBold: big,
                                bigFontSize: bigFontSize,
                                smallFontSize: smallFontSize,
                                showUnitInSuperscript: true,
                                boldColor: boldColor)
            } else {
                return StatText(label: "PACE",
                                value: model.recorder.pace,
                                formatting: .timestampLimitedToOneHour,
                                unit: "/\(model.recorder.unit.abbreviation.uppercased())",
                                isBold: big,
                                bigFontSize: bigFontSize,
                                smallFontSize: smallFontSize,
                                showUnitInSuperscript: big,
                                boldColor: boldColor)
            }
        case .activeCalories:
            return StatText(label: "CAL",
                            value: model.recorder.totalCalories,
                            formatting: .integer,
                            isBold: big,
                            bigFontSize: bigFontSize,
                            smallFontSize: smallFontSize,
                            showUnitInSuperscript: big,
                            boldColor: boldColor)
        case .heartRate:
            return StatText(label: "HR",
                            value: model.recorder.currentHeartRate,
                            formatting: .integer,
                            unit: "BPM",
                            isBold: big,
                            bigFontSize: bigFontSize,
                            smallFontSize: smallFontSize,
                            showUnitInSuperscript: big,
                            boldColor: boldColor)
        case .elevation:
            return StatText(label: "EL GAIN",
                            value: model.recorder.elevationAscended,
                            formatting: .integer,
                            unit: "M",
                            isBold: big,
                            bigFontSize: bigFontSize,
                            smallFontSize: smallFontSize,
                            showUnitInSuperscript: true,
                            boldColor: boldColor)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            switch model.recorder.goal.type {
            case .open:
                if model.recorder.activityType.showsRoute {
                    statText(for: .distance, big: true)
                } else {
                    statText(for: .time, big: true)
                }
            case .distance:
                statText(for: .distance, big: true)
            case .time:
                statText(for: .time, big: true)
            case .calories:
                statText(for: .activeCalories, big: true)
            }

            if model.recorder.goal.type == .open {
                Spacer()
            } else {
                Spacer()
                GoalProgressBar(model: model)
                Spacer()
            }

            switch model.recorder.goal.type {
            case .open, .distance:
                if model.recorder.activityType.showsRoute {
                    VStack {
                        HStack {
                            statText(for: .time)
                            Spacer()
                            statText(for: .elevation)
                        }
                        
                        HStack {
                            statText(for: .paceOrSpeed)
                            Spacer()
                            statText(for: .activeCalories)
                        }
                    }
                } else {
                    HStack {
                        statText(for: .activeCalories)
                        Spacer()
                        statText(for: .heartRate)
                    }
                }
            case .time:
                if model.recorder.activityType.showsRoute {
                    VStack {
                        HStack {
                            statText(for: .distance)
                            Spacer()
                            statText(for: .elevation)
                        }

                        HStack {
                            statText(for: .paceOrSpeed)
                            Spacer()
                            statText(for: .activeCalories)
                        }
                    }
                } else {
                    HStack {
                        statText(for: .activeCalories)
                        Spacer()
                        statText(for: .heartRate)
                    }
                }
            case .calories:
                if model.recorder.activityType.showsRoute {
                    VStack {
                        HStack {
                            statText(for: .time)
                            Spacer()
                            statText(for: .distance)
                        }

                        HStack {
                            statText(for: .paceOrSpeed)
                            Spacer()
                            statText(for: .elevation)
                        }
                    }
                } else {
                    HStack {
                        statText(for: .time)
                        Spacer()
                        statText(for: .heartRate)
                    }
                }
            }

            Spacer()
        }
        .padding([.leading, .trailing], 8)
    }
}

struct PageIndicator: View {
    var pageIdx: Int
    var numberOfPages: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<numberOfPages) { idx in
                Circle()
                    .foregroundColor(.white)
                    .frame(width: 6, height: 6)
                    .opacity(idx == pageIdx ? 1 : 0.5)
                    .scaleEffect(idx == pageIdx ? 1 : 0.8)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 100)
                .foregroundColor(Color.black.opacity(0.9))
                .opacity(pageIdx == (numberOfPages - 1) ? 1 : 0)
        )
    }
}

fileprivate struct HeartRate: View {
    @Environment(\.scenePhase) var scenePhase
    @ObservedObject var model: WatchRecordingViewModel
    @State private var animate: Bool = false
    @State private var viewId: Int = 0

    var bigFontSize: CGFloat {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        return screenWidth * 0.25
    }

    var smallFontSize: CGFloat {
        let screenWidth = WKInterfaceDevice.current().screenBounds.width
        return screenWidth * 0.0875
    }

    struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: rect.height + 4))
            return path
        }
    }

    var heartRateLabel: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    let hr = model.recorder.currentHeartRate
                    let hrString = (hr <= 0) ? "--" : String(Int(hr))
                    Text(hrString)
                        .foregroundColor(.white)
                        .font(.system(size: bigFontSize, weight: .bold, design: .monospaced))

                    ZStack {
                        Image("glyph_heart")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: bigFontSize * 0.85)

                        Image("glyph_heart")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: bigFontSize * 0.85)
                            .scaleEffect(animate ? 2.2 : 1)
                            .opacity(animate ? 0 : 1)
                            .blur(radius: animate ? 10 : 0)
                            .animation(.easeOut(duration: 180 / model.recorder.currentHeartRate)
                                .repeatForever(autoreverses: false),
                                       value: animate)
                            .id(viewId)

                        Image("glyph_heart")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: bigFontSize * 0.85)
                            .scaleEffect(animate ? 2.2 : 1)
                            .opacity(animate ? 0 : 1)
                            .blur(radius: animate ? 10 : 0)
                            .animation(.easeOut(duration: 180 / model.recorder.currentHeartRate)
                                .repeatForever(autoreverses: false)
                                .delay(60 / model.recorder.currentHeartRate),
                                       value: animate)
                            .id(viewId + 1)

                        Image("glyph_heart")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: bigFontSize * 0.85)
                            .scaleEffect(animate ? 2.2 : 1)
                            .opacity(animate ? 0 : 1)
                            .blur(radius: animate ? 10 : 0)
                            .animation(.easeOut(duration: 180 / model.recorder.currentHeartRate)
                                .repeatForever(autoreverses: false)
                                .delay(120 / model.recorder.currentHeartRate),
                                       value: animate)
                            .id(viewId + 2)
                    }
                    .zIndex(-1)
                }
                .frame(height: bigFontSize)

                Text("BPM")
                    .font(.system(size: smallFontSize, weight: .medium, design: .default))
                    .frame(height: smallFontSize)
            }
            Spacer()
        }
        .padding([.leading, .trailing], 8)
        .onChange(of: model.recorder.currentHeartRate) { _ in
            animate = false
            viewId += 1
            DispatchQueue.main.async {
                animate = true
            }
        }
        .onChange(of: scenePhase) { _ in
            animate = false
            viewId += 1
            DispatchQueue.main.async {
                animate = true
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            heartRateLabel

            if let heartRateGraphImage = model.heartRateGraphImage {
                Image(uiImage: heartRateGraphImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding([.leading, .trailing], 6)
            }

            Spacer()
        }
    }
}

fileprivate struct Toast: View {
    @Binding var isVisible: Bool
    var text: String
    var icon: Image
    var showsLoadingIndicator: Bool = false

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            if showsLoadingIndicator {
                ProgressView()
                    .tint(.white)
                    .frame(width: 25, height: 25)
            } else {
                icon
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.white)
                    .frame(width: 25, height: 25)
            }
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundColor(.white)
            Spacer()
        }
        .scaleEffect(isVisible ? 1 : 0.9)
        .opacity(isVisible ? 1 : 0)
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.2), value: isVisible)
    }
}

fileprivate struct StatsTimelineSchedule: TimelineSchedule {
    var startDate: Date

    init(from startDate: Date) {
        self.startDate = startDate
    }

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> PeriodicTimelineSchedule.Entries {
        PeriodicTimelineSchedule(from: startDate,
                                 by: mode == .lowFrequency ? 1.0 : 1.0 / 30.0)
        .entries(from: startDate,
                 mode: mode)
    }
}

struct WatchRecordingView: View {
    @ObservedObject var model: WatchRecordingViewModel
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.scenePhase) var scenePhase

    @State private var hasAppeared: Bool = false
    @State private var crownValue: Double = 0.0
    @State private var crownStart: Double = 0.0
    @State private var pageWidth: CGFloat = WKInterfaceDevice.current().screenBounds.width

    @State private var tabPageIdx: Int = 0

    @State private var goalHalfwayToastVisible: Bool = false
    @State private var goalCompleteToastVisible: Bool = false
    @State private var activityFinishedToastVisible: Bool = false
    @State private var discardToastVisible: Bool = false

    private func stopAction() {
        WKInterfaceDevice.current().play(.click)
        if model.recorder.duration <= 5 {
            model.recorder.stopAndDiscardActivity()
        } else {
            Task(priority: .background) {
                await model.recorder.finish()
            }
        }
    }

    private func playPauseAction() {
        WKInterfaceDevice.current().play(.click)
        Task {
            switch model.recorder.state {
            case .ready:
                try await model.recorder.start()
            case .recording:
                try await model.recorder.pause()
            case .paused:
                try await model.recorder.resume()
            default: break
            }
        }
    }

    var numberOfPages: Int {
        if model.recorder.activityType.showsRoute {
            switch model.recorder.state {
            case .saved, .discarded:
                return 2
            default:
                return 4
            }
        } else {
            switch model.recorder.state {
            case .saved, .discarded:
                return 1
            default:
                return 3
            }
        }
    }

    var body: some View {
        ZStack {
            ZStack {
                if model.recorder.activityType.showsRoute {
                    ZStack {
                        BackgroundMap(model: model)

                        if let rect = model.visibleMapRect {
                            ZStack {
                                RouteLine(locations: model.recorder.locations,
                                          mapRect: rect)
                                .stroke(Color.white, lineWidth: 2)
                                .ignoresSafeArea()

                                UserLocationView(model: model)
                            }
                            .drawingGroup()
                        }
                    }
                    .opacity(model.recorder.state != .ready ? 1 : 0.0)
                    .blur(radius: tabPageIdx == 3 ? 0.0 : 10.0)
                    .opacity(tabPageIdx == 3 ? 1.0 : 0.4)
                    .animation(.linear(duration: 0.2).delay(0.3), value: model.recorder.state)
                    .animation(.easeInOut(duration: 0.25), value: tabPageIdx)
                } else {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(model.recorder.activityType.glyphName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .opacity(0.15)
                                .opacity(model.recorder.state == .ready ? 0 : 1)
                        }
                    }
                }

                LinearGradient(colors: [.black, .clear],
                               startPoint: .top,
                               endPoint: UnitPoint(x: 0.5, y: 0.35))
                .ignoresSafeArea()

                TabView(selection: $tabPageIdx) {
                    if !model.recorder.isFinished {
                        Controls(model: model)
                            .tag(0)
                        TimelineView(.periodic(from: model.recorder.startDate, by: 1.0)) { _ in
                            Stats(model: model)
                        }
                        .tag(1)
                        HeartRate(model: model)
                            .tag(2)
                        if model.recorder.activityType.showsRoute {
                            Color.clear
                                .tag(3)
                        }
                    } else {
                        ScrollView(.vertical) {
                            Stats(model: model)
                                .padding(.bottom, 40)
                        }
                        .mask {
                            LinearGradient(colors: [.clear, .black],
                                           startPoint: .top,
                                           endPoint: UnitPoint(x: 0.5, y: 0.25))
                            .ignoresSafeArea()
                        }
                        .tag(0)

                        if model.recorder.activityType.showsRoute {
                            Color.clear
                                .tag(1)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut(duration: 0.6), value: tabPageIdx)
                .mask {
                    ZStack {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: UnitPoint(x: 0.5, y: 0.9),
                                       endPoint: .bottom)
                        Color.black
                            .opacity((model.recorder.activityType.showsRoute && tabPageIdx == numberOfPages - 1) ? 0.1 : 1.0)
                            .animation(.easeInOut(duration: 0.25), value: tabPageIdx)
                    }
                    .ignoresSafeArea()
                }
                .opacity(model.recorder.state == .ready ? 0 : 1)
                .animation(.easeOut(duration: 0.25), value: model.recorder.state)

                VStack {
                    Spacer()
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.adOrangeLighter)
                            Text("Done")
                                .font(.system(size: 15, weight: .medium, design: .default))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(TransparentButtonStyle())
                    .frame(height: 40)
                    .offset(y: 5)
                }
                .opacity((model.recorder.state == .saved || model.recorder.state == .discarded) ? 1 : 0)
                .scaleEffect((model.recorder.state == .saved || model.recorder.state == .discarded) ? 1 : 0.9)
                .animation(.easeInOut(duration: 0.15), value: model.recorder.state)
                .padding([.leading, .trailing], 8)

                if model.recorder.state != .locationPermissionNeeded {
                    CountdownView() {
                        Task {
                            try await model.recorder.start()
                        }
                        tabPageIdx = 1
                    }
                }

                GeometryReader { geo in
                    VStack {
                        HStack {
                            if scenePhase == .inactive {
                                TimelineView(.periodic(from: model.recorder.startDate, by: 1.0)) { _ in
                                    StateLabel(state: model.recorder.state)
                                }
                            } else {
                                StateLabel(state: model.recorder.state)
                            }
                            Spacer()
                        }
                        .frame(height: geo.safeAreaInsets.top)
                        .scenePadding(.horizontal)
                        .offset(x: DeviceType.isAppleWatchUltra ? 10 : 0,
                                y: DeviceType.isAppleWatchUltra ? 2 : 1)
                        Spacer()
                    }
                    .ignoresSafeArea()
                    .opacity(hasAppeared ? 1 : 0)
                }
            }
            .blur(radius: goalHalfwayToastVisible || goalCompleteToastVisible || activityFinishedToastVisible || discardToastVisible ? 30.0 : 0)
            .brightness(goalHalfwayToastVisible || goalCompleteToastVisible || activityFinishedToastVisible || discardToastVisible ? -0.1 : 0)
            .animation(.easeInOut(duration: 0.35),
                       value: goalHalfwayToastVisible || goalCompleteToastVisible || activityFinishedToastVisible || discardToastVisible)

            ZStack {
                Toast(isVisible: $goalHalfwayToastVisible, text: "Halfway point", icon: Image(systemName: "circle.lefthalf.filled"))
                Toast(isVisible: $goalCompleteToastVisible, text: "Goal complete", icon: Image(systemName: "checkmark.circle.fill"))
                Toast(isVisible: $activityFinishedToastVisible,
                      text: model.recorder.state == .saving ? "Saving" : "Activity finished",
                      icon: Image(systemName: "checkmark.circle.fill"),
                      showsLoadingIndicator: model.recorder.state == .saving)
                Toast(isVisible: $discardToastVisible, text: "Activity discarded", icon: Image(systemName: "info.circle.fill"))
            }
            .zIndex(Double.greatestFiniteMagnitude)
        }
        .focusable()
        .digitalCrownRotation($crownValue,
                              from: -1 * Double.greatestFiniteMagnitude,
                              through: Double.greatestFiniteMagnitude,
                              isContinuous: true,
                              isHapticFeedbackEnabled: false,
                              onIdle: {
            guard model.recorder.state != .ready else {
                return
            }

            crownStart = crownValue
        })
        .contentShape(Rectangle())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    hasAppeared = true
                }
            }
        }
        .onChange(of: model.recorder.state) { [oldValue = model.recorder.state] newValue in
            if newValue == .saving {
                activityFinishedToastVisible = true
            }

            if newValue == .saved {
                WKInterfaceDevice.current().play(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    activityFinishedToastVisible = false
                }
            }

            if newValue == .discarded {
                discardToastVisible = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    presentationMode.wrappedValue.dismiss()
                }
            }

            if oldValue == .paused && newValue == .recording && tabPageIdx == 0 {
                tabPageIdx = 1
                crownStart = crownValue
            }
        }
        .onChange(of: model.recorder.goalHalfwayPointReached) { newValue in
            goalHalfwayToastVisible = true
            WKInterfaceDevice.current().play(.notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                goalHalfwayToastVisible = false
            }
        }
        .onChange(of: model.recorder.goalMet) { newValue in
            goalCompleteToastVisible = true
            WKInterfaceDevice.current().play(.notification)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                goalCompleteToastVisible = false
            }
        }
        .onChange(of: crownValue) { newValue in
            guard model.recorder.state != .ready else {
                return
            }

            if (crownValue - crownStart) > 0 {
                guard tabPageIdx < (numberOfPages - 1) else {
                    crownStart = crownValue
                    return
                }

                guard (crownValue - crownStart) > 30 else {
                    return
                }

                WKInterfaceDevice.current().play(.click)
                tabPageIdx += 1
                crownStart = crownValue
            } else if (crownValue - crownStart) < 0 {
                guard tabPageIdx > 0 else {
                    crownStart = crownValue
                    return
                }

                guard (crownValue - crownStart) < -30 else {
                    return
                }

                WKInterfaceDevice.current().play(.click)
                tabPageIdx -= 1
                crownStart = crownValue
            }
        }
    }
}

struct WatchRecordingView_Previews: PreviewProvider {
    static var previews: some View {
        let recorder = WatchActivityRecorder(activityType: .bikeRide,
                                             goal: RecordingGoal(type: .distance, unit: .miles, target: 20),
                                             unit: .miles)
        WatchRecordingView(model: WatchRecordingViewModel(recorder: recorder))
            .previewDevice("Apple Watch Series 7 - 44mm")
    }
}

class WatchRecordingViewModel: ObservableObject {
    @ObservedObject private(set) var recorder: WatchActivityRecorder
    @Published var visibleMapRect: MKMapRect?
    @Published var heartRateGraphImage: UIImage?
    private var observers: Set<AnyCancellable> = []

    init(recorder: WatchActivityRecorder) {
        print("spawned new recorder")
        self.recorder = recorder

        self.recorder.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }.store(in: &observers)

        self.recorder.$heartRateData.sink { [weak self] newValue in
            Task(priority: .userInitiated) {
                let data = HeartRateSampleAggregator.aggregateRawSamples(newValue)
                self?.heartRateGraphImage = await WatchHeartRateGraphGenerator.generateGraphImage(data)
            }
        }.store(in: &observers)

        // Generate initial HR graph image
        Task(priority: .userInitiated) {
            heartRateGraphImage = await WatchHeartRateGraphGenerator.generateGraphImage([])
        }
    }
}

fileprivate struct DeviceType {
    static var isAppleWatchUltra: Bool {
        return WKInterfaceDevice.current().screenBounds.width == 205
    }
}

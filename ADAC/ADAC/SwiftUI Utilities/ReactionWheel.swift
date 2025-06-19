// Licensed under the Any Distance Source-Available License
//
//  ReactionWheel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/28/23.
//

import SwiftUI
import SwiftUIX

struct ReactionWheel: ViewModifier {
    var showPress: Bool = true
    @Binding var showsReactions: Bool
    @Binding var showingReactions: Bool
    @Binding var touchingDown: Bool
    var onReact: ((PostReactionType) -> Void)?
    var onTap: (() -> Void)?

    let doubleTapMaxDuration: Double = 0.24

    @State private var longPressLocation = CGPoint.zero
    @State private var reactionDragLocation = CGPoint.zero
    @State private var hoveredReactionType: PostReactionType?
    @State private var longPressTimer: Timer?
    @State private var lastTouchDownDate: Date = Date()
    @State private var lastOnTapDate: Date = Date()

    private let longPressDuration: TimeInterval = 0.3
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    var reactionsWheel: some View {
        ZStack {
            Button {
                showingReactions = false
            } label: {
                Image(systemName: .xmarkCircleFill)
                    .font(.system(size: 30.0))
                    .opacity(0.5)
            }
            .buttonStyle(ScalingPressButtonStyle())
            .opacity(showingReactions ? 1.0 : 0.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.5),
                       value: showingReactions)

            let scale: CGFloat = showingReactions ? 1.0 : 0.2
            ForEach(PostReactionType.availableTypes.enumerated().map { $0 }, id: \.element) { idx, type in
                let rotation: CGFloat = 360.0 * CGFloat(idx) / CGFloat(PostReactionType.availableTypes.count)
                let hoveredScale: CGFloat = (type == hoveredReactionType) ? 1.5 : 1.0

                VStack {
                    Button {
                        hoveredReactionType = type
                        showingReactions = false
                        notificationGenerator.notificationOccurred(.success)
                        onReact?(type)
                    } label: {
                        Text(type.emoji)
                            .font(.system(size: 36.0))
                            .rotationEffect(.degrees(-1.0 * rotation))
                            .padding(.top, 20.0)
                    }
                    .buttonStyle(ScalingPressButtonStyle())
                    .scaleEffect(x: scale, y: scale)
                    .opacity(showingReactions ? 1.0 : 0.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5)
                        .delay(showingReactions ? Double(idx) * 0.06 : 0.0)
                        .delay(type == hoveredReactionType ? 0.5 : 0.0),
                               value: showingReactions)
                    .scaleEffect(x: hoveredScale, y: hoveredScale)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5),
                               value: hoveredReactionType)
                    Spacer()
                }
                .frame(height: 212.0)
                .rotationEffect(.degrees(rotation))
            }
        }
        .position(longPressLocation)
        .animation(.none, value: longPressLocation)
    }

    func body(content: Content) -> some View {
        content
            .if(showPress) { view in
                view
                    .scaleEffect(x: touchingDown ? 0.95 : 1.0,
                                 y: touchingDown ? 0.95 : 1.0)
                    .opacity(touchingDown ? 0.8 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: touchingDown)
            }
            .overlay {
                let scale = showingReactions ? 1.0 : 0.2
                ZStack {
                    Color.black.opacity(0.01)
                        .opacity(showingReactions ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.4), value: showingReactions)
                        .onTapGesture {
                            showingReactions = false
                        }

                    DarkBlurView()
                        .mask {
                            Circle()
                        }
                        .frame(width: 212.0, height: 212.0)
                        .position(longPressLocation)
                        .animation(.none, value: longPressLocation)
                        .scaleEffect(x: scale, y: scale)
                        .opacity(showingReactions ? 1.0 : 0.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showingReactions)

                    reactionsWheel
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.3), value: showingReactions)
            }
            .overlay {
                TouchEventView { location, view in
                    // Touches began
                    hoveredReactionType = nil
                    touchingDown = true
                    longPressTimer?.invalidate()

                    let prevTouchDownDate = lastTouchDownDate
                    lastTouchDownDate = Date()
                    if showsReactions,
                       lastTouchDownDate.timeIntervalSince(prevTouchDownDate) < doubleTapMaxDuration,
                       var location = location  {
                        location.x = location.x.clamped(to: 106.0...(UIScreen.main.bounds.width - 106.0))
                        withoutAnimation {
                            longPressLocation = location
                        }
                        showingReactions = true
                        return
                    }

                    longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDuration,
                                                          repeats: false) { _ in
                        guard touchingDown else {
                            return
                        }

                        longPressTimer?.invalidate()
                        longPressTimer = nil

                        if showsReactions, !showingReactions, var location = location {
                            location.x = location.x.clamped(to: 106.0...(UIScreen.main.bounds.width - 106.0))
                            withoutAnimation {
                                longPressLocation = location
                            }
                            showingReactions = true
                            view.findContainingScrollView()?.isScrollEnabled = false
                        }
                    }
                } touchMoved: { location, view in
                    // Touches moved
                    if let location = location {
                        reactionDragLocation = location
                    }

                    var hoveredType: PostReactionType?
                    for (i, type) in PostReactionType.availableTypes.enumerated() {
                        let angle: CGFloat = 2.0 * .pi * CGFloat(i-1) / CGFloat(PostReactionType.availableTypes.count)
                        let m: CGFloat = 100.0
                        let s: CGFloat = 100.0
                        let rect = CGRect(x: longPressLocation.x + m * cos(angle) - (s / 2.0),
                                          y: longPressLocation.y + m * sin(angle) - (s / 2.0),
                                          width: s,
                                          height: s)

                        if rect.contains(reactionDragLocation) {
                            hoveredType = type
                        }
                    }
                    if hoveredType != nil && hoveredType != hoveredReactionType && showingReactions {
                        impactGenerator.impactOccurred()
                    }
                    hoveredReactionType = hoveredType
                } touchCancelled: { location, view in
                    // Touches cancelled
//                    showingReactions = false
                    touchingDown = false
//                    findContainingScrollView(for: view)?.isScrollEnabled = true
                } touchEnded: { location, view in
                    // Touches ended
                    if !showingReactions {
                        if showsReactions {
                            DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapMaxDuration) {
                                let prevOnTapDate = lastOnTapDate
                                lastOnTapDate = Date()
                                // Prevent slow double taps from triggering tap event twice
                                if lastOnTapDate.timeIntervalSince(prevOnTapDate) > 1.0 {
                                    onTap?()
                                }
                            }
                        } else {
                            onTap?()
                            lastOnTapDate = Date()
                        }
                    }

                    if let hoveredReactionType = hoveredReactionType {
                        showingReactions = false
                        notificationGenerator.notificationOccurred(.success)
                        onReact?(hoveredReactionType)
                    }
                    touchingDown = false
                    view.findContainingScrollView()?.isScrollEnabled = true
                }
                .opacity((!touchingDown && showingReactions) ? 0.0 : 1.0)
            }
    }
}

struct TouchEventView: UIViewRepresentable {
    var touchBegan: ((_ location: CGPoint?, _ view: TouchEventPassingUIView) -> Void)?
    var touchMoved: ((_ location: CGPoint?, _ view: TouchEventPassingUIView) -> Void)?
    var touchCancelled: ((_ location: CGPoint?, _ view: TouchEventPassingUIView) -> Void)?
    var touchEnded: ((_ location: CGPoint?, _ view: TouchEventPassingUIView) -> Void)?

    func makeUIView(context: Context) -> TouchEventPassingUIView {
        let touchPassingView = TouchEventPassingUIView()
        touchPassingView.backgroundColor = UIColor.clear
        touchPassingView.touchesBeganHandler = { touches, event in
            let firstLocation = touches.first?.location(in: touchPassingView)
            touchBegan?(firstLocation, touchPassingView)
        }

        touchPassingView.touchesMovedHandler = { touches, event in
            let firstLocation = touches.first?.location(in: touchPassingView)
            touchMoved?(firstLocation, touchPassingView)
        }

        touchPassingView.touchesCancelledHandler = { touches, event in
            let firstLocation = touches.first?.location(in: touchPassingView)
            touchCancelled?(firstLocation, touchPassingView)
        }

        touchPassingView.touchesEndedHandler = { touches, event in
            let firstLocation = touches.first?.location(in: touchPassingView)
            touchEnded?(firstLocation, touchPassingView)
        }

        return touchPassingView
    }

    func updateUIView(_ uiView: TouchEventPassingUIView, context: Context) {}
}

class TouchEventPassingUIView: UIView {
    var touchesBeganHandler: ((_ touches: Set<UITouch>, _ event: UIEvent?) -> Void)?
    var touchesMovedHandler: ((_ touches: Set<UITouch>, _ event: UIEvent?) -> Void)?
    var touchesCancelledHandler: ((_ touches: Set<UITouch>, _ event: UIEvent?) -> Void)?
    var touchesEndedHandler: ((_ touches: Set<UITouch>, _ event: UIEvent?) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        touchesBeganHandler?(touches, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        touchesMovedHandler?(touches, event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        touchesCancelledHandler?(touches, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        touchesEndedHandler?(touches, event)
    }
}

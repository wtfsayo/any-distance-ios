// Licensed under the Any Distance Source-Available License
//
//  SwiftUIExtensions.swift
//  ADAC
//
//  Created by Daniel Kuntz on 12/9/21.
//

import SwiftUI
import UIKit

#if !TARGET_IS_EXTENSION && !os(watchOS)
import SwiftUIX
#endif

extension Color {
    #if !TARGET_IS_EXTENSION && !os(watchOS)
    static let adDarkGreen = Color(hexadecimal: "#109832")!
    static let goalGreen = Color(hexadecimal: "B2FE00")!
    static let goalOrange = Color(hexadecimal: "ED7E11")!
    #endif

    static let adOrange = Color(uiColor: .adOrange)
    static let adOrangeLighter = Color(uiColor: .adOrangeLighter)
    static let adYellow = Color(uiColor: .adYellow)
    static let adRed = Color(uiColor: .adRed)
    static let adBrown = Color(uiColor: .adBrown)
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    func onTouchDownUpEvent(changeState: @escaping (ButtonState) -> Void) -> some View {
        modifier(TouchDownUpEventModifier(changeState: changeState))
    }

    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

extension Font {
    static func greedMedium(size: CGFloat) -> Font {
        if let uiFont = UIFont(name: "Greed Extended", size: size) {
            return Font(uiFont)
        }

        return Font(UIFont.systemFont(ofSize: size, weight: .regular, width: .expanded))
    }

    static func presicav(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let uiFont: UIFont = {
            switch weight {
            case .bold:
                return .presicav(size: size, weight: .bold)
            case .heavy:
                return .presicav(size: size, weight: .heavy)
            default:
                return .presicav(size: size, weight: .regular)
            }
        }()

        return Font(uiFont)
    }
}

enum ButtonState {
    case pressed
    case notPressed
}

struct TouchDownUpEventModifier: ViewModifier {
    @GestureState private var isPressed = false
    let changeState: (ButtonState) -> Void

    public func body(content: Content) -> some View {
        let drag = DragGesture(minimumDistance: 0)
            .updating($isPressed) { (value, gestureState, transaction) in
                gestureState = true
            }

        return content
            .gesture(drag)
            .onChange(of: isPressed, perform: { (pressed) in
                if pressed {
                    self.changeState(.pressed)
                } else {
                    self.changeState(.notPressed)
                }
            })
    }

    public init(changeState: @escaping (ButtonState) -> Void) {
        self.changeState = changeState
    }
}

var smoothCurveAnimation: Animation {
    return Animation.timingCurve(0.36, 0.33, 0.28, 1.06, duration: 1.0)
}

struct BlurModifier: ViewModifier {
    var radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

struct BlurOpacityTransition: ViewModifier {
    var speed: Double = 1.0
    var delay: Double = 0.0
    var anchor: UnitPoint = .center

    public func body(content: Content) -> some View {
        content
            .transition(.modifier(active: BlurModifier(radius: 8),
                                  identity: BlurModifier(radius: 0))
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.9, anchor: anchor))
                .animation(smoothCurveAnimation.speed(speed).delay(delay)))
    }
}

#if !TARGET_IS_EXTENSION && !os(watchOS)
struct SlideModifier: ViewModifier {
    var offset: CGFloat

    func body(content: Content) -> some View {
        content.offset(x: offset)
    }
}

struct SlideTransition: ViewModifier {
    var speed: Double = 1.0
    
    public func body(content: Content) -> some View {
        content
            .transition(.modifier(active: SlideModifier(offset: UIScreen.main.bounds.width),
                                  identity: SlideModifier(offset: 0))
                .animation(smoothCurveAnimation.speed(speed)))
    }
}
#endif

struct AlertButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .background {
                Rectangle()
                    .fill(configuration.isPressed ? Color.white.opacity(0.2) : Color.white.opacity(0.01))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
    }
}

struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }

    typealias Value = CGPoint
}

struct ScrollViewOffsetModifier: ViewModifier {
    let coordinateSpace: String
    @Binding var offset: CGPoint

    func body(content: Content) -> some View {
        ZStack {
            content
            GeometryReader { proxy in
                let x = proxy.frame(in: .named(coordinateSpace)).minX
                let y = proxy.frame(in: .named(coordinateSpace)).minY
                Color.clear.preference(key: ScrollViewOffsetPreferenceKey.self, value: CGPoint(x: x * -1, y: y * -1))
            }
        }
        .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
            offset = value
        }
    }
}

extension View {
    func readingScrollView(from coordinateSpace: String, into binding: Binding<CGPoint>) -> some View {
        modifier(ScrollViewOffsetModifier(coordinateSpace: coordinateSpace, offset: binding))
    }

    #if !os(watchOS) && !TARGET_IS_EXTENSION
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif
}

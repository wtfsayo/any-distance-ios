// Licensed under the Any Distance Source-Available License
//
//  SuperDistanceView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/16/24.
//

import UIKit
import SwiftUI

fileprivate struct TopGradient: View {
    @Binding var scrollViewOffset: CGFloat
    var isTransparent: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Color.black
                    .frame(height: UIApplication.shared.topViewController?.view.safeAreaInsets.top ?? 0.0)
                    .opacity(isTransparent ? 0.0 : 1.0)
                Image("gradient_bottom_ease_in_out")
                    .resizable(resizingMode: .stretch)
                    .scaleEffect(y: -1)
                    .frame(width: UIScreen.main.bounds.width, height: 60.0)
                    .opacity(isTransparent ? 0.0 : 1.0)
            }
            .overlay {
                VariableBlurView(maxBlurRadius: isTransparent ? 5.0 : 2.0)
                    .offset(y: -10)
            }
            Spacer()
        }
        .opacity((1.0 - (scrollViewOffset / 50.0)).clamped(to: 0...1))
        .ignoresSafeArea()
    }
}

fileprivate struct TitleView: View {
    var shownInOnboarding: Bool = false
    @Binding var scrollViewOffset: CGFloat

    var body: some View {
        VStack(alignment: .leading) {
            Spacer()
                .frame(height: 45.0)

            let p = (scrollViewOffset / -80.0)

            HStack {
                Image("glyph_superdistance_white")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .modifier(GradientEffect())
                    .frame(width: 140)
                    .shadow(color: .black.opacity(0.6), radius: 10.0)
                    .scaleEffect((0.6 + ((1.0 - p) * 0.4)).clamped(to: 0.6...1.0),
                                 anchor: .leading)
                    .offset(y: scrollViewOffset < 0 ? 0 : (0.3 * scrollViewOffset))
                    .offset(y: (-22.0 * p).clamped(to: -22.0...0.0))
                Spacer()
            }
            .overlay {
                HStack {
                    Spacer()
                    Button {
                        if shownInOnboarding {
                            UIApplication.shared.transitionToTabBar()
                        } else {
                            Analytics.logEvent("X tapped", "Super Distance", .buttonTap)
                            UIApplication.shared.topViewController?.dismiss(animated: true)
                        }
                    } label: {
                        if shownInOnboarding {
                            Text("Skip")
                                .font(.system(size: 14.0))
                                .foregroundColor(.white)
                                .opacity(0.5)
                                .padding(8)
                                .contentShape(Rectangle())
                                .opacity((1.0 - (scrollViewOffset / -70)).clamped(to: 0...1) * 1.0)
                                .blur(radius: (10 * scrollViewOffset / -70).clamped(to: 0...10))
                        } else {
                            Image(systemName: .xmarkCircleFill)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                                .contentShape(Rectangle())
                                .opacity((1.0 - (scrollViewOffset / -70)).clamped(to: 0...1) * 1.0)
                                .blur(radius: (10 * scrollViewOffset / -70).clamped(to: 0...10))
                        }
                    }
                    .offset(x: 2.0)
                    .offset(y: scrollViewOffset < 0 ? 0 : (0.3 * scrollViewOffset))
                }
            }
        }
        .padding(.top, -22.5)
        .padding([.leading, .trailing], 15.0)
    }
}

struct InfiniteScrollView: View {
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    let size: CGFloat = 100.0
    @State private var offset: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0.0) {
                ForEach(1...8, id: \.self) { idx in
                    Image("sd_photo_\(idx)")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                }
                ForEach(1...8, id: \.self) { idx in
                    Image("sd_photo_\(idx)")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                }
            }
            .offset(x: offset)
            .animation(.linear(duration: 0.1), value: offset)
            .onReceive(timer) { _ in
                offset -= 1
                let maxOffset = -800.0
                if offset < maxOffset {
                    withAnimation(.none) {
                        offset = 0
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SuperDistanceView: View {
    var shownInOnboarding: Bool = false

    @State var scrollViewOffset: CGFloat = 0.0
    @State var isLoading: Bool = false
    @State var showingFailureAlert: Bool = false
    @StateObject private var iapManager = iAPManager.shared

    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    let screenName = "Super Distance"

    var andiVideoURL: URL? = {
        let videoName = "progress-andi-\(Int.random(in: 1...5)).mp4"
        return URL(string: "https://anydistancecounts.s3-us-east-2.amazonaws.com/progress-andi/" + videoName)
    }()

    func buyTapped() {
        Analytics.logEvent("Start free trial", screenName, .buttonTap)
        isLoading = true
        iAPManager.shared.buyYearlyProduct { state in
            isLoading = false
            if state == .failed {
                showingFailureAlert = true
                Analytics.logEvent("Purchase Failed", screenName, .otherEvent)
            } else {
                Analytics.logEvent("Purchase Succeeded", screenName, .otherEvent)
                Task(priority: .userInitiated) {
                    await ActivitiesData.shared.load()
                }

                if shownInOnboarding {
                    UIApplication.shared.transitionToTabBar()
                } else {
                    UIApplication.shared.topViewController?.dismiss(animated: true)
                }
            }
        }
    }

    func restoreTapped() {
        Analytics.logEvent("Restore", screenName, .buttonTap)
        isLoading = true
        iAPManager.shared.restorePurchases { state in
            isLoading = false
            if state == .failed {
                showingFailureAlert = true
                Analytics.logEvent("Restore Failed", screenName, .otherEvent)
            } else {
                Analytics.logEvent("Restore Succeeded", screenName, .otherEvent)

                if shownInOnboarding {
                    UIApplication.shared.transitionToTabBar()
                } else {
                    UIApplication.shared.topViewController?.dismiss(animated: true)
                }
            }
        }
    }

    var body: some View {
        ZStack {
            ReadableScrollView(offset: $scrollViewOffset, 
                               showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8.0) {
                    InfiniteScrollView()
                    .padding([.leading, .trailing], -15.0)
                    .padding(.top, 84.0)

                    if !iAPManager.shared.isSubscribed {
                        Text("Your first week's on us")
                            .font(.greedMedium(size: 28.0))
                            .foregroundColor(.white)
                            .padding(.top, 20.0)

                        Text("Try Super Distance free for 7 days")
                            .font(.system(size: 14.0))
                            .foregroundColor(.white)
                            .opacity(0.6)
                    }

                    VStack(spacing: 0.0) {
                        HStack(spacing: 8.0) {
                            Spacer()
                            HStack {
                                Text("Free")
                                    .font(.system(size: 13.0, weight: .medium))
                            }
                            .frame(width: 50.0)

                            HStack {
                                Spacer()
                                Image(systemName: .starSquareFill)
                                    .modifier(GradientEffect())
                                Spacer()
                            }
                            .frame(width: 50.0)
                            .frame(height: 45.0)
                            .background {
                                Rectangle()
                                    .cornerRadius(8.0, corners: [.topLeft, .topRight])
                                    .foregroundColor(Color.white.opacity(0.16))
                            }
                        }

                        Group {
                            FeatureRow(imageName: "activity_run",
                                       title: "Activity Tracking",
                                       subtitle: "Unlimited tracking on iPhone & Watch",
                                       includedFree: true,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_graph",
                                       title: "Detailed Stats Data",
                                       subtitle: "Beautiful stats for all your workouts",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_graphs_route2d",
                                       title: "Garmin & Wahoo Integration",
                                       subtitle: "Import data from Garmin & Wahoo",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_goals",
                                       title: "Unlimited Goals",
                                       subtitle: "Create unlimited goals",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_lightning",
                                       title: "Live Activity",
                                       subtitle: "Track workouts on your lock screen",
                                       includedFree: false,
                                       includedPro: true)
                        }

                        Group {
                            FeatureRow(imageName: "glyph_graphs_route3d",
                                       title: "3D & AR Routes",
                                       subtitle: "Share your route in 3D & AR",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_graphs_heartRate",
                                       title: "Heart Rate Graph",
                                       subtitle: "Share your heart rate graph",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_graphs_elevation",
                                       title: "Elevation Graph",
                                       subtitle: "Share your elevation graph",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_layouts",
                                       title: "Extra Colors & Layouts",
                                       subtitle: "Dozens of fun layouts and colors",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_film_effects",
                                       title: "Photo Film Effects",
                                       subtitle: "Powered by Hipstamatic™",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_ad_medal",
                                       title: "Super Medal",
                                       subtitle: "Achievement for supporting us",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_beta",
                                       title: "Beta Access",
                                       subtitle: "Join our exclusive beta group",
                                       includedFree: false,
                                       includedPro: true)
                            FeatureRow(imageName: "glyph_appicon",
                                       title: "Super App Icons",
                                       subtitle: "Choose from 12 app icons",
                                       includedFree: false,
                                       includedPro: true,
                                       fadeOut: true)
                        }
                    }
                    .padding(.top, 10.0)

                    VStack(spacing: 6.0) {
                        HStack {
                            Image(systemName: .trophyFill)
                                .font(.system(size: 30.0))
                                .modifier(GradientEffect())
                                .overlay {
                                    Image(systemName: .appleLogo)
                                        .foregroundColor(.black)
                                        .font(.system(size: 11.0))
                                        .offset(y: -8.2)
                                }
                        }
                        HStack(spacing: 5.0) {
                            Image(systemName: .laurelLeading)
                                .font(.system(size: 13.0, weight: .bold))
                            Text("Apple Design Award Winner")
                                .font(.system(size: 15.0, weight: .semibold))
                            Image(systemName: .laurelTrailing)
                                .font(.system(size: 13.0, weight: .bold))
                        }
                        .opacity(0.6)
                        .padding(.bottom, 8.0)

                        Text("Any Distance is a design-forward fitness tracker that delivers workout stats in a variety of eye-popping and easily shareable formats: dynamic charts and graphs, rotating 3D maps complete with elevation reports, even AR. And its in-app collectibles provide a fun incentive to go that extra mile. Any Distance raises the bar for the fitness-tracking genre.")
                            .multilineTextAlignment(.center)
                            .font(.system(size: 15))
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12.0)
                            .fill(Color.white.opacity(0.1))
                    }
                    .padding(.top, 20.0)
                    .overlay {
                        VStack {
                            HStack {
                                Spacer()
                                Image("andi_side_point")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 65.0)
                                    .offset(y: -20.0)
                            }
                            Spacer()
                        }
                        .padding(.trailing, -15.0)
                    }
                    .padding(.top, 25.0)

                    HStack(spacing: 4.0) {
                        Spacer()
                        Image(systemName: .starFill)
                        Image(systemName: .starFill)
                        Image(systemName: .starFill)
                        Image(systemName: .starFill)
                        ZStack {
                            Image(systemName: .starFill)
                                .foregroundColor(.white.opacity(0.4))
                            Image(systemName: .starFill)
                                .mask {
                                    Rectangle()
                                        .padding(.trailing, 8.0)
                                }
                        }
                        Spacer()
                    }
                    .foregroundColor(.adOrangeLighter)
                    .padding(.top, 20.0)

                    Text("4.7")
                        .font(.presicav(size: 23.0, weight: .bold))
                        .maxWidth(1000000)
                    Text("Based on over 2100 reviews")
                        .font(.system(size: 14.0))
                        .opacity(0.6)
                        .maxWidth(1000000)
                        .padding(.bottom, 16.0)

                    ZStack {
                        HStack {
                            Spacer()
                            LoopingVideoView(videoUrl: andiVideoURL!, videoGravity: .resizeAspect)
                                .frame(width: 130.0, height: 130.0)
                                .offset(x: 8.0)
                                .blendMode(.lighten)
                        }

                        VStack(alignment: .leading, spacing: 7.0) {
                            HStack(spacing: 6.0) {
                                Image(systemName: .lightbulbCircleFill)
                                    .font(.system(size: 11.0, weight: .bold))
                                    .offset(y: -0.5)
                                Text("Andi Fact")
                                    .font(.system(size: 11.0, weight: .semibold, design: .monospaced))
                            }
                            .foregroundColor(.white)
                            .opacity(0.5)

                            HStack {
                                Text("Super Distance members do 3x as many workouts per week on average.")
                                    .font(.system(size: 17.0, weight: .medium))
                                    .layoutPriority(1)
                                Spacer()
                                    .frame(minWidth: 120.0)
                            }
                        }
                    }

                    VStack(alignment: .center) {
                        PrivacyAndTerms()
                            .padding(.top, 30.0)

                        if !iAPManager.shared.isSubscribed {
                            Button {
                                restoreTapped()
                            } label: {
                                Text("Restore Purchases")
                                    .font(.system(size: 14.0, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding()
                            }

                            Spacer()
                                .frame(height: 140.0)
                        } else {
                            Spacer()
                                .frame(height: 20.0)
                        }
                    }
                    .frame(maxWidth: 100000)
                }
                .padding([.leading, .trailing], 15.0)
            }

            ZStack {
                TopGradient(scrollViewOffset: $scrollViewOffset, 
                            isTransparent: shownInOnboarding)
                VStack {
                    TitleView(shownInOnboarding: shownInOnboarding,
                              scrollViewOffset: $scrollViewOffset)
                    Spacer()
                }
            }

            if !iAPManager.shared.isSubscribed {
                VStack {
                    Spacer()
                    VStack {
                        VStack {
                            Text("Get 7 days free, then only \(iapManager.yearlyProduct?.localizedPrice ?? "$49.99") / year")
                                .font(.system(size: 13.0))
                                .opacity(0.6)
                            Button {
                                feedbackGenerator.impactOccurred()
                                buyTapped()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 30.0, style: .continuous)
                                        .foregroundColor(.white)
                                    Text("Start your free trial")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Color.black)
                                }
                            }
                            .buttonStyle(ScalingPressButtonStyle())
                            .frame(height: 50)
                        }
                        .padding([.leading, .trailing], 15.0)
                        .padding(.bottom, 12.0)
                    }
                    .maxWidth(100000)
                    .background {
                        VStack(spacing: 0.0) {
                            Image("layout_gradient")
                                .resizable(resizingMode: .stretch)
                                .frame(height: 60.0)
                            Color.black
                                .padding(.bottom, -150)
                        }
                        .offset(y: -60.0)
                        .ignoresSafeArea()
                    }
                }
            }
        }
        .background(shownInOnboarding ? Color.clear : Color.black)
        .blur(radius: isLoading ? 30.0 : 0.0)
        .animation(.easeInOut(duration: 0.1), value: isLoading)
        .overlay {
            VStack {
                if isLoading {
                    ProgressView()
                        .modifier(BlurOpacityTransition(speed: 1.8))
                }
            }
        }
        .alert("Something went wrong", isPresented: $showingFailureAlert) {
            Button("Ok") {}
        } message: {
            Text("Try again later or reach out to us at support@anydistance.club")
        }
    }
}

struct FeatureRow: View {
    var imageName: String
    var title: String
    var subtitle: String
    var includedFree: Bool
    var includedPro: Bool
    var fadeOut: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3.0) {
                HStack {
                    Image(uiImage: UIImage(systemName: imageName) ?? UIImage(named: imageName) ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18.0, height: 18.0)
                    Text(title)
                        .font(.system(size: 14.0, weight: .medium))
                }
                Text(subtitle)
                    .font(.system(size: 14.0))
                    .opacity(0.6)
            }
            .padding([.top, .bottom], 8.0)

            Spacer()

            HStack(alignment: .center, spacing: 8.0) {
                VStack {
                    if includedFree {
                        Image(systemName: .checkmarkCircleFill)
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 50.0)

                VStack {
                    Spacer()
                    if includedPro {
                        Image(systemName: .checkmarkCircleFill)
                            .foregroundStyle(Color.white)
                    }
                    Spacer()
                }
                .frame(width: 50.0)
                .background {
                    Color.white
                        .opacity(0.1)
                        .if(fadeOut) { view in
                            view
                                .mask {
                                Image("layout_top_gradient")
                                    .resizable(resizingMode: .stretch)
                            }
                                .scaleEffect(x: 1, y: 1.5, anchor: .top)
                        }
                }
            }
        }
    }
}

#Preview {
    SuperDistanceView(shownInOnboarding: true)
}

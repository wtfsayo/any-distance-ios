// Licensed under the Any Distance Source-Available License
//
//  ConnectHealth.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/14/23.
//

import SwiftUI

struct Scroller<Content: View>: View {
    var contentWidth: CGFloat
    var reversed: Bool = true
    var duration: TimeInterval = 20
    var content: (() -> Content)

    @State var xOffset: CGFloat = 0

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                content()
                content()
            }
            .offset(x: xOffset, y: 0)
        }
        .disabled(true)
        .onAppear {
            if reversed {
                xOffset = -1 * contentWidth
            }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                if reversed {
                    xOffset = 0
                } else {
                    xOffset = -contentWidth
                }
            }
        }
    }
}

struct AppIconScroller: View {
    let iconWidth: CGFloat = 75
    let iconSpacing: CGFloat = 20

    @State private var firstRow: AnyView?
    @State private var secondRow: AnyView?
    @State private var thirdRow: AnyView?

    var iconNames: [String] {
        return ["icon_fitness",
                "icon_strava",
                "icon_garmin",
                "icon_nrc",
                "icon_peloton",
                "icon_runkeeper",
                "icon_wahoo",
                "icon_fitbod",
                "icon_ot",
                "icon_future",
                "icon_addidasrunning",
                "icon_alltrails",
                "icon_gentler"]
    }

    func generateRow() -> some View {
        let shuffledIconNames = iconNames.shuffled()
        return HStack(spacing: iconSpacing) {
            ForEach(0..<shuffledIconNames.count) { idx in
                let name = shuffledIconNames[idx]
                if idx == shuffledIconNames.count - 1 {
                    Image(name)
                        .resizable()
                        .frame(width: iconWidth, height: iconWidth)
                        .padding(.trailing, iconSpacing)
                } else {
                    Image(name)
                        .resizable()
                        .frame(width: iconWidth, height: iconWidth)
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: iconSpacing) {
            let iconCount = CGFloat(iconNames.count)
            if let firstRow = firstRow, let secondRow = secondRow, let thirdRow = thirdRow {
                Scroller(contentWidth: iconWidth * iconCount + iconSpacing * iconCount,
                         reversed: true,
                         duration: 24) {
                    firstRow
                }
                .frame(height: iconWidth)
                Scroller(contentWidth: iconWidth * iconCount + iconSpacing * iconCount,
                         reversed: false,
                         duration: 30) {
                    secondRow
                }
                .frame(height: iconWidth)
                Scroller(contentWidth: iconWidth * iconCount + iconSpacing * iconCount,
                         reversed: true,
                         duration: 36) {
                    thirdRow
                }
                .frame(height: iconWidth)
            }
        }
        .mask {
            LinearGradient(colors: [.clear, .black, .black, .black, .black, .black, .clear],
                           startPoint: .leading,
                           endPoint: .trailing)
        }
        .onAppear {
            firstRow = AnyView(generateRow())
            secondRow = AnyView(generateRow())
            thirdRow = AnyView(generateRow())
        }
    }
}

/// Onboarding screen that shows a looping animation for apps AD connects with, and navigates to
/// Apple Health auth. Not used in the current onboarding sequence as of 4.08.2
struct ConnectHealth: View {
    var model: OnboardingViewModel

    let screenName = "AC Onboarding - Connect Health"

    private func connectWithHealth() {
        HealthKitActivitiesStore.shared.requestAuthorization(with: screenName) {
            model.advanceState()
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Spacer()
            AppIconScroller()
            Spacer()

            OnboardingTitleAndSubtitle(model: model)
                .padding(.bottom, 16)
            ADWhiteButton(title: model.state.buttonText) {
                connectWithHealth()
            }

            Button {
                UIApplication.shared.open(Links.privacyCommitment)
            } label: {
                Text(model.state.bottomButtonText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
            }
        }
        .padding([.leading, .trailing], 20)
        .padding(.bottom, 20)
        .onAppear {
            Analytics.logEvent(screenName, screenName, .screenViewed)
        }
    }
}

struct ConnectHealth_Previews: PreviewProvider {
    static var model: OnboardingViewModel {
        let model = OnboardingViewModel()
        model.state = .connectHealth
        return model
    }

    static var previews: some View {
        ConnectHealth(model: model)
    }
}

// Licensed under the Any Distance Source-Available License
//
//  OnboardingWelcomeView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/14/23.
//

import SwiftUI

/// Container within OnboardingWelcomeView that shows 4 looping video slides with a .lighten
/// blend mode so they blend appropriately with GradientAnimationView in OnboardingView.
struct OnboardingHeroVideo: View {
    @ObservedObject var model: OnboardingViewModel

    var body: some View {
        VStack {
            TabView(selection: $model.state) {
                VStack {
                    Text("Welcome to")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(.white)
                    Image("wordmark")
                }
                .tag(OnboardingState.start)
                LoopingVideoView(videoUrl: Bundle.main.url(forResource: "onboarding-slide-2", withExtension: "mp4")!,
                                 videoGravity: .resizeAspect)
                .tag(OnboardingState.welcome1)
                LoopingVideoView(videoUrl: Bundle.main.url(forResource: "onboarding-slide-4", withExtension: "mp4")!,
                                 videoGravity: .resizeAspect)
                .tag(OnboardingState.welcome2)
                LoopingVideoView(videoUrl: Bundle.main.url(forResource: "onboarding-slide-1", withExtension: "mp4")!,
                                 videoGravity: .resizeAspect)
                .tag(OnboardingState.welcome3)
                LoopingVideoView(videoUrl: Bundle.main.url(forResource: "onboarding-slide-3", withExtension: "mp4")!,
                                 videoGravity: .resizeAspect)
                .tag(OnboardingState.welcome4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .scaleEffect(x: 0.85, y: 0.85)
            .animation(.easeInOut(duration: 0.4), value: model.state)

            Spacer()
                .frame(height: 150)
        }
        .blendMode(.lighten)
    }
}

/// First slide in the onboarding sequence. Shows a carousel with 4 looping videos with different titles / subtitles,
/// "Start" button that navigates to Apple Health auth
struct OnboardingWelcomeView: View {
    @ObservedObject var model: OnboardingViewModel
    @State var welcomePage: Int = 0
    @State var welcomePageTimer: Timer?

    let screenName = "AC Onboarding - Welcome"

    private func resetTimer() {
        welcomePageTimer?.invalidate()
        welcomePageTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { _ in
            welcomePage = (welcomePage + 1) % 5
        }
    }

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                OnboardingTitleAndSubtitle(model: model)
                PageControl(currentPage: $welcomePage, numberOfPages: 5)
                    .padding(.bottom, 120)
            }
            .padding([.leading, .trailing], 25)

            VStack(spacing: 20.0) {
                Spacer()

                Button {
                    model.advancePastWelcome()
                    Analytics.logEvent("Next - \(model.state.rawValue)", screenName, .screenViewed)
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.white)
                            .frame(width: 110.0,
                                   height: 44.0)
                        HStack {
                            Text("Start")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.black)
                                .modifier(BlurOpacityTransition(speed: 2.0))
                            Image(systemName: .arrowRight)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                }

                PrivacyAndTerms()
            }
            .frame(width: UIScreen.main.bounds.width)
            .padding(.bottom, 20)

            VStack {
                Image("onboarding_medal")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 45, height: 80)
                Spacer()
            }
            .padding(.top, 40)
        }
        .onChange(of: welcomePage) { newValue in
            model.state = OnboardingState(rawValue: newValue)!
            resetTimer()
        }
        .onChange(of: model.state) { newValue in
            welcomePage = model.state.rawValue
        }
        .onAppear {
            resetTimer()
            Analytics.logEvent(screenName, screenName, .screenViewed)
        }
        .onDisappear {
            welcomePageTimer?.invalidate()
            welcomePageTimer = nil
        }
    }
}

struct OnboardingWelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingWelcomeView(model: OnboardingViewModel())
    }
}

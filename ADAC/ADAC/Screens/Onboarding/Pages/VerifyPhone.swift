// Licensed under the Any Distance Source-Available License
//
//  VerifyPhone.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/28/23.
//

import SwiftUI
import Sentry

/// Onboarding slide that shows a phone code verification field
struct VerifyPhone: View {
    enum VerifyPhoneState {
        case enteringCode
        case loading
        case codeIncorrect
        case codeCorrect

        var textColor: Color {
            switch self {
            case .enteringCode, .loading:
                return .white
            case .codeIncorrect:
                return .adRed
            case .codeCorrect:
                return .green
            }
        }
    }

    @ObservedObject var model: OnboardingViewModel
    @FocusState var focusedField: OnboardingFocusedField?
    @State private var state: VerifyPhoneState = .enteringCode
    @State private var resendSecondsRemaining: Int = 6
    @State private var timer: Timer?

    let screenName = "AC Onboarding - Verify Phone"

    func resetTimer() {
        resendSecondsRemaining = 60
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            resendSecondsRemaining -= 1
            if resendSecondsRemaining == 0 {
                timer?.invalidate()
                timer = nil
            }
        }
    }

    func checkCode() {
        guard state != .codeCorrect else {
            return
        }

        state = .loading
        Task {
            do {
                let codeCorrect = try await model.checkVerification()
                if codeCorrect {
                    Analytics.logEvent("Correct code entered", screenName, .otherEvent)
                    state = .codeCorrect
                    model.setUserPhone()
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        model.state = .pickUsername
                    }
                } else {
                    state = .codeIncorrect
                    Analytics.logEvent("Incorrect code entered", screenName, .otherEvent)
                }
            } catch {
                Analytics.logEvent("Error checking code", screenName, .otherEvent)
                SentrySDK.capture(error: error)
                state = .codeIncorrect
                UIApplication.shared.topViewController?.showFailureToast(with: error)
                return
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            OnboardingTitleAndSubtitle(model: model)

            ZStack {
                Rectangle()
                    .fill(state != .codeIncorrect ? state.textColor.opacity(0.2) : .white.opacity(0.2))
                    .cornerRadius(10, style: .continuous)
                    .animation(.easeInOut(duration: 0.2), value: state)
                TextField("000000", text: $model.phoneVerificationCode)
                    .focused($focusedField, equals: .phoneVerification)
                    .textContentType(.oneTimeCode)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .font(.system(size: 23, design: .monospaced))
                    .tint((state == .codeCorrect || state == .loading) ? Color.clear : Color.adOrangeLighter)
                    .multilineTextAlignment(.center)
                    .foregroundColor(state.textColor)
                    .animation(.easeInOut(duration: 0.2), value: state)

                HStack {
                    Spacer()
                    ProgressView()
                        .opacity(state == .loading ? 1.0 : 0.0)
                        .padding(.trailing, 16)
                }
            }
            .frame(height: 50)

            Button {
                // resend code
                Analytics.logEvent("Resend code", screenName, .buttonTap)
                resetTimer()
                model.verifyPhone()
            } label: {
                Group {
                    if resendSecondsRemaining >= 1 {
                        Text("Resend code in \(resendSecondsRemaining) second\(resendSecondsRemaining >= 2 ? "s" : "")")
                    } else {
                        Text("Resend code")
                    }
                }
                .animation(.none, value: resendSecondsRemaining)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .medium))
                .background(Color.black.opacity(0.01))
            }
            .opacity(resendSecondsRemaining == 0 ? 1.0 : 0.5)
            .allowsHitTesting(resendSecondsRemaining == 0)
            .animation(.easeInOut(duration: 0.2), value: resendSecondsRemaining)
        }
        .padding([.leading, .trailing], 30)
        .padding(.bottom, 20)
        .onAppear {
            Analytics.logEvent(screenName, screenName, .screenViewed)
            focusedField = .phoneVerification
            resetTimer()
        }
        .onChange(of: model.phoneVerificationCode) { newValue in
            state = .enteringCode
            model.phoneVerificationCode = String(newValue.dropLast(max(0, newValue.count - 6)))
            if newValue.count == 6 {
                checkCode()
            }
        }
    }
}

// Licensed under the Any Distance Source-Available License
//
//  EnterPhone.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/28/23.
//

import SwiftUI

/// Onboarding slide that shows a custom phone number field with validation
struct EnterPhone: View {
    @ObservedObject var model: OnboardingViewModel
    @StateObject var textFieldDelegate = TextFieldDelegate()
    @FocusState var focusedField: OnboardingFocusedField?

    let screenName = "AC Onboarding - Enter Phone"
    let allCodes = CountryCode.prefixCodes.map { $0 }.sorted(by: \.key).reversed()

    class TextFieldDelegate: NSObject, ObservableObject, UITextFieldDelegate {
        weak var model: OnboardingViewModel?

        func textField(_ textField: UITextField,
                       shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            guard let model = model else { return true }
            guard let text = textField.text else { return false }
            var newString = (text as NSString).replacingCharacters(in: range, with: string)
            if newString.hasPrefix("+") {
                // This is an autofill number
                model.selectedCountryCode = CountryCode.code(for: newString)
                if let numberPrefix = CountryCode.prefixCodes[model.selectedCountryCode] {
                    newString = String(newString.dropFirst(numberPrefix.count + 1))
                }
            }

            let formatted = format(with: CountryCode.format(for: model.selectedCountryCode),
                                   phone: newString)
            let withAreaCode = ("+" + (CountryCode.prefixCodes[model.selectedCountryCode] ?? "") + formatted).e164FormattedPhoneNumber()
            if withAreaCode.count > CountryCode.maxCount(for: model.selectedCountryCode) {
                return false
            }
            model.phoneNumber = formatted
            textField.text = formatted
            return false
        }

        func format(with mask: String, phone: String) -> String {
            guard let model = model else {
                return phone
            }

            let maxCount = CountryCode.maxCount(for: model.selectedCountryCode)
            var numbers = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            numbers = String(numbers.dropFirst(max(numbers.count - maxCount, 0)))
            var result = ""
            var index = numbers.startIndex // numbers iterator

            // iterate over the mask characters until the iterator of numbers ends
            for ch in mask where index < numbers.endIndex {
                if ch == "X" {
                    // mask requires a number in this place, so take the next one
                    result.append(numbers[index])

                    // move numbers iterator to the next index
                    index = numbers.index(after: index)
                } else {
                    result.append(ch) // just append a mask character
                }
            }

            // append remaining digits if necessary
            if index != numbers.endIndex && result.count < maxCount {
                while index != numbers.endIndex && result.count < maxCount {
                    result.append(numbers[index])
                    index = numbers.index(after: index)
                    if result.count == numbers.count {
                        break
                    }
                }
            }

            return result
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            OnboardingTitleAndSubtitle(model: model)

            HStack(spacing: 3) {
                ZStack {
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .cornerRadius(10, corners: [.topLeft, .bottomLeft])
                    Text("+" + (CountryCode.prefixCodes[model.selectedCountryCode] ?? ""))
                        .foregroundColor(.white)
                        .font(.system(size: 23, design: .monospaced))
                }
                .overlay {
                    Menu {
                        ForEach(allCodes.reversed(), id: \.key) { code in
                            Button {
                                model.selectedCountryCode = code.key
                            } label: {
                                if code.key == model.selectedCountryCode {
                                    Label("\(code.key) +\(code.value)", systemImage: .checkmark)
                                } else {
                                    Text("\(code.key) +\(code.value)")
                                }
                            }
                        }
                    } label: {
                        Color.black.opacity(0.01)
                    }
                }
                .frame(width: 80)

                ZStack {
                    Rectangle()
                        .fill(.white.opacity(0.2))
                        .cornerRadius(10, corners: [.topRight, .bottomRight])
                    TextField(CountryCode.placeholder(for: model.selectedCountryCode),
                              text: $model.phoneNumber)
                        .introspectTextField(customize: { textField in
                            textFieldDelegate.model = model
                            textField.delegate = textFieldDelegate
                        })
                        .focused($focusedField, equals: .phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.numberPad)
                        .submitLabel(.next)
                        .font(.system(size: 23, design: .monospaced))
                        .tint(Color.adOrangeLighter)
                        .padding(.leading, 20)
                }
            }
            .frame(height: 50)

            ADWhiteButton(title: model.state.buttonText) {
                Analytics.logEvent("Verify phone", screenName, .buttonTap)
                model.verifyPhone()
            }
            .opacity(model.isPhoneValid ? 1.0 : 0.5)
            .allowsHitTesting(model.isPhoneValid)
            .animation(.easeInOut(duration: 0.2), value: model.phoneNumber)

            Button {
                Analytics.logEvent("Privacy commitment", screenName, .buttonTap)
                UIApplication.shared.topViewController?.openUrl(withString: Links.privacyCommitment.absoluteString)
            } label: {
                Text(model.state.bottomButtonText)
                    .foregroundColor(.white)
                    .font(.system(size: 15, weight: .medium))
                    .background(Color.black.opacity(0.01))
            }
            .frame(height: 30)
        }
        .padding([.leading, .trailing], 30)
        .padding(.bottom, 20)
        .onAppear {
            Analytics.logEvent(screenName, screenName, .screenViewed)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .phoneNumber
            }
        }
    }
}

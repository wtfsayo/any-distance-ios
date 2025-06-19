// Licensed under the Any Distance Source-Available License
//
//  RecordingPrivacyView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 8/25/22.
//

import SwiftUI

protocol RecordingPrivacyViewDelegate: AnyObject {
    func startActivity()
}

struct RecordingPrivacyView: View {
    @Environment(\.presentationMode) var presentationMode
    weak var delegate: RecordingPrivacyViewDelegate?

    func dismissAndRecord() {
        UIApplication.shared.topViewController?.dismiss(animated: true, completion: {
            delegate?.startActivity()
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            NavBar(title: "Your Privacy", closeTitle: "Close") {
                dismissAndRecord()
            }

            ScrollView {
                VStack(alignment: .center, spacing: 16) {
                    Image("glyph_phone_privacy_health")
                        .padding(.top, 20)
                        .scaleEffect(0.9)

                    Text("Any Distance is privacy driven.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 34, weight: .bold, design: .default))
                    Text("We do not sell or store any activity data. Any activity tracked is kept securely and privately in Apple Health.\n\nWe respect your privacy at every step of the way and we will not compromise that for the sake of monetizing the app. If you have any questions, please contact us.")
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button {
                            dismissAndRecord()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.adOrangeLighter)
                                Text("Got it")
                                    .font(.system(size: 17, weight: .semibold, design: .default))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(height: 55)

                        Button {
                            UIApplication.shared.topViewController?.sendEmail(to: "hello@anydistance.club",
                                                                              subject: "",
                                                                              message: "")
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(uiColor: .white))
                                Text("Contact us")
                                    .font(.system(size: 17, weight: .semibold, design: .default))
                                    .foregroundColor(.black)
                            }
                        }
                        .frame(height: 55)
                    }

                    VStack(alignment: .center, spacing: 0) {
                        Button {
                            UIApplication.shared.topViewController?.openUrl(withString: Links.privacyPolicy.absoluteString)
                        } label: {
                            Text("Terms & Conditions and Privacy Policy")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundColor(.white)
                                .opacity(0.6)
                                .padding()
                        }

                        Button {
                            UIApplication.shared.topViewController?.openUrl(withString: Links.privacyCommitment.absoluteString)
                        } label: {
                            Text("Privacy Commitment")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundColor(.white)
                                .opacity(0.6)
                        }
                    }
                    .padding(.top, -8)

                    Spacer()
                }
                .padding([.leading, .trailing], 20)
            }
            .background(Color.black)
        }
    }
}

struct RecordingPrivacyView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingPrivacyView()
    }
}

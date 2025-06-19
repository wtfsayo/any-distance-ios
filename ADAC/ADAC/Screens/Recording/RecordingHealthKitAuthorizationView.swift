// Licensed under the Any Distance Source-Available License
//
//  RecordingHealthKitAuthorizationView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/27/22.
//

import SwiftUI

struct RecordingHealthKitAuthorizationView: View {
    @Environment(\.presentationMode) var presentationMode
    var onAuthorize: (() -> Void)

    func authorizeHealth() {
        HealthKitActivitiesStore.shared.requestAuthorization(with: "Recording Health Auth") {
            DispatchQueue.main.async {
                presentationMode.dismiss()
                onAuthorize()
            }
        }
    }

    private func checkAuthorization() {
        if HealthKitActivitiesStore.shared.isAuthorizedToShare() {
            DispatchQueue.main.async {
                presentationMode.dismiss()
                onAuthorize()
            }
        }
    }

    var body: some View {
        VStack {
            Spacer()

            VStack {
                VStack(spacing: 14.0) {
                    Image("glyph_phone_privacy_health")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120.0, height: 120.0)
                    Text("Any Distance securely saves activities to Apple Health. Authorize Apple Health to save this activity.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    ADWhiteButton(title: "Authorize Health",
                                  action: authorizeHealth)
                    Button {
                        UIApplication.shared.open(Links.privacyCommitment)
                    } label: {
                        Text("Our Privacy Commitment →")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(10)
                    }
                }
                .padding([.leading, .trailing], 30)
                .padding(.top, 30)
            }
            .background {
                Color.black
                    .cornerRadius([.topLeading, .topTrailing], 24.0)
                    .ignoresSafeArea()
                    .padding(.bottom, -100)
            }
        }
        .background(Color.clear)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkAuthorization()
        }
    }
}

struct RecordingHealthKitAuthorizationView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingHealthKitAuthorizationView(onAuthorize: {})
    }
}

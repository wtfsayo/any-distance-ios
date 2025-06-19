// Licensed under the Any Distance Source-Available License
//
//  RecordingEarlyAccessView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/1/22.
//

import SwiftUI

struct EarlyAccessCloseHeader: View {
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        HStack {
            Text("Early Access")
                .font(.presicavRegular(size: 18))
                .foregroundColor(.white)
                .padding(.leading, 20)
            Spacer()
            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Close")
                    .font(.system(size: 18, weight: .medium, design: .default))
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

fileprivate struct Info: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity Tracking done right.")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundColor(.white)

            Text("Coming soon to iPhone: A fun, fresh, privacy first activity tracking experience.")
                .foregroundColor(.white)

            Text("Get an access code by following us on Twitter or Instagram where we will be sharing them regularly.")
                .foregroundColor(.white)

            HStack(spacing: 0) {
                Button {
                    UIApplication.shared.topViewController?.openUrl(withString: Links.twitter.absoluteString)
                } label: {
                    Image("glyph_twitter_37")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30)
                        .padding()
                }

                Button {
                    UIApplication.shared.topViewController?.openUrl(withString: Links.instagram.absoluteString)
                } label: {
                    Image("glyph_insta_37")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30)
                        .padding()
                }

                Spacer()
            }
            .offset(x: -14)
        }
    }
}

struct RecordingEarlyAccessView: View {
    static let screenName: String = "Early Access"
    
    var tabBar: ADTabBar?

    @State private var accessCode: String = ""
    @FocusState private var textFieldFocused: Bool
    @State private var loading: Bool = false

    func redeemCode() {
        loading = true
        Task(priority: .userInitiated) {
            do {
                _ = try await InviteCodeManager.shared.useSingleUseCode(accessCode)
                CollectibleManager.grantActivityTrackingEarlyAccessCollectible()
                CloudKitUserManager.shared.saveCurrentUser()

                DispatchQueue.main.async {
                    Analytics.logEvent("Code Redeemed", RecordingEarlyAccessView.screenName, .otherEvent)
                    UIApplication.shared.topViewController?.dismiss(animated: true) {
                        tabBar?.startActivity(showUnlockedState: true)
                    }
                }
            } catch let error as InviteCodeError {
                DispatchQueue.main.async {
                    Analytics.logEvent("Error Redeeming Code",
                                       RecordingEarlyAccessView.screenName,
                                       .otherEvent,
                                       withParameters: ["error" : error.description])
                    showToast(withError: error)
                }
            }
            loading = false
        }
    }

    func showToast(withError error: InviteCodeError) {
        let toastModel = ToastView.Model(title: error.description,
                                         description: error.blurb,
                                         image: UIImage(systemName: "exclamationmark.triangle.fill"),
                                         maxPerSession: 100)
        let toast = ToastView(model: toastModel)
        let topVC = UIApplication.shared.topViewController
        topVC?.view.present(toast: toast,
                            insets: .init(top: 0, left: 0, bottom: 180, right: 0))
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            toast.dismiss()
        }
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack {
                        LoopingVideoView(videoUrl: Bundle.main.url(forResource: "privacy-first",
                                                                   withExtension: "mov"))
                        .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                        .padding(.top, 25)

                        Spacer()
                    }

                    VStack {
                        EarlyAccessCloseHeader()
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Spacer()
                                    .frame(height: (geo.size.height - 540).clamped(to: 180...CGFloat.greatestFiniteMagnitude))
                                Info()
                                    .background {
                                        LinearGradient(colors: [.black, .black, .clear],
                                                       startPoint: .bottom,
                                                       endPoint: .top)
                                        .padding(.top, -120)
                                    }
                                Spacer()
                                    .frame(height: 180)
                            }
                            .padding([.leading, .trailing], 20)
                        }
                        .maxWidth(.infinity)
                    }
                }
                .ignoresSafeArea(.keyboard)
            }

            VStack(spacing: 12) {
                Button {
                    textFieldFocused = false
                } label: {
                    Color.black.opacity(0.01)
                }
                .padding(.top, 55)
                .allowsHitTesting(textFieldFocused)

                VStack(spacing: 12) {
                    Text("ENTER ACCESS CODE")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)

                    AccessCodeField(accessCode: $accessCode,
                                    isFocused: $textFieldFocused)

                    Button {
                        redeemCode()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.adOrangeLighter)

                            if !loading {
                                Text("Get Early Access")
                                    .font(.system(size: 17, weight: .medium, design: .default))
                                    .foregroundColor(.black)
                            } else {
                                ProgressView()
                                    .tint(Color.black)
                            }
                        }
                        .frame(height: 55)
                    }
                    .disabled(accessCode.count != 6)
                    .brightness(accessCode.count != 6 ? -0.2 : 0.0)
                    .saturation(accessCode.count != 6 ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: accessCode)
                    .allowsHitTesting(!loading)

                    HStack(spacing: 5) {
                        Image("glyph_superdistance_white")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 10)
                            .offset(y: -1)
                        Text("members get early access immediately.")
                            .font(.system(size: 11, weight: .semibold, design: .default))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 8)
                }
                .background {
                    LinearGradient(colors: [.black, .black, .black, .black, .clear],
                                   startPoint: .bottom,
                                   endPoint: .top)
                    .allowsHitTesting(false)
                    .padding(.top, -45)
                }
            }
            .padding([.leading, .trailing], 20)
        }
        .onChange(of: textFieldFocused) { newValue in
            if newValue == false && accessCode.count == 6 {
                redeemCode()
            }
        }
    }
}

struct RecordingEarlyAccessView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingEarlyAccessView(tabBar: nil)
            .previewDevice("iPhone 13 Pro")
    }
}

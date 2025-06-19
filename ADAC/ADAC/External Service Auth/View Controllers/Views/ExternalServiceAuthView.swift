// Licensed under the Any Distance Source-Available License
//
//  ExternalServiceAuthView.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/18/22.
//

import SwiftUI

struct PrivacyItem: View {
    var title: String
    var description: String
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(UIColor.adGreen))
            VStack(alignment: .leading, spacing: 4.0) {
                Text(title)
                    .font(.system(size: 18.0, weight: .regular, design: .default))
                Text(description)
                    .font(.system(size: 14.0, weight: .regular, design: .default))
                    .foregroundColor(Color(UIColor.adGray4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RoundedButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .default))
            .foregroundColor(Color.black)
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(27, style: .continuous)
            .scaleEffect(x: configuration.isPressed ? 0.95 : 1,
                         y: configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct ExternalServiceAuthView: View {
    @ObservedObject var viewModel: ExternalServiceAuthViewModel
    @State private var showingHealthAlert: Bool = false
    
    private var externalService: ExternalService {
        viewModel.externalService
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavBar(title: "Sync Connect", closeTitle: "Cancel") {
                viewModel.cancel()
            }
            VStack(alignment: .center, spacing: 10.0) {
                // main content
                Spacer()
                VStack(alignment: .leading, spacing: 18.0) {
                    Image(externalService.imageNameLarge)
                    Text("Sync your past and future activities from \(externalService.displayName)™ with Any Distance.")
                    Text("Your privacy is critical to us.")
                }
                .padding([.bottom], 18.0)
                .font(.system(size: 18.0, weight: .regular, design: .default))
                .foregroundColor(Color(UIColor.adGray4))
                VStack(spacing: 20.0) {
                    PrivacyItem(title: "Read route data from \(externalService.displayName)™",
                                description: "Data is stored locally on your device.")
                    PrivacyItem(title: "Aggregate distance stats",
                                description: "Distances are added to your Total Distance stat.")
                    PrivacyItem(title: "We will never sell your data",
                                description: "Your data is yours, not ours.")
                }
                .frame(maxWidth: .infinity)
                Spacer()

                if externalService == .appleHealth {
                    Button("Open Settings") {
                        showingHealthAlert = true
                    }
                    .buttonStyle(RoundedButtonStyle())
                } else {
                    // bottom buttons
                    if viewModel.isAuthorized {
                        Button("Disconnect from \(externalService.displayName)") {
                            viewModel.disconnect()
                        }
                        .buttonStyle(RoundedButtonStyle())
                    } else if viewModel.isAuthorizationExpired {
                        Button("Reconnect to \(externalService.displayName)") {
                            viewModel.connect()
                        }
                        .buttonStyle(RoundedButtonStyle())
                    } else {
                        Button("Connect to \(externalService.displayName)") {
                            viewModel.connect()
                        }
                        .buttonStyle(RoundedButtonStyle())
                    }
                }

                VStack(spacing: 9.0) {
                    if let terms = URL(string: "https://anyd.ist/inapp_legal") {
                        Button("Connection Terms & Conditions and Privacy Policy") {
                            viewModel.presentURL(url: terms)
                        }
                    }
                    if let privacy = URL(string: "https://anyd.ist/inapp_privacy_commitment") {
                        Button("Privacy Commitment") {
                            viewModel.presentURL(url: privacy)
                        }
                    }
                }
                .padding([.top], 12.0)
                .font(.system(size: 13.0, weight: .regular, design: .default))
                .foregroundColor(Color(UIColor.adGray3))
            }
            .padding([.leading, .trailing], 22.0)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .background(Color(UIColor.adGray1))
        .alert("Apple Health Permissions", isPresented: $showingHealthAlert) {
            Button("Open Settings") {
                let url = URL(string: UIApplication.openSettingsURLString)!
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            Button("Cancel") {}
        } message: {
            Text("To change Apple Health permissions, go to Settings > Health > Data Access & Devices > Any Distance")
        }
    }
    
}

struct ExternalServiceAuthView_Previews: PreviewProvider {
    static var previews: some View {
        ExternalServiceAuthView(viewModel: ExternalServiceAuthViewModel(with: .garmin))
    }
}

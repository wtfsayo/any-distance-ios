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

    var body: some View {
        VStack {
            Spacer()
                .onTapGesture {
                    presentationMode.dismiss()
                }

            VStack {
                NavBar(title: "Health Permissions", closeTitle: "Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .cornerRadius([.topLeft, .topRight], 12)

                ScrollView {
                    VStack(alignment: .center, spacing: 16) {
                        LoopingVideoView(videoUrl: Bundle.main.url(forResource: "health-permissions", withExtension: "mp4"),
                                         videoGravity: .resizeAspect)
                        .frame(width: 273, height: 350)
                        .cornerRadius(16, style: .continuous)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Oops! Any Distance needs read & write permissions to record an activity. Don't worry, it's an easy fix.")
                            Text("Navigate to Settings → Health → Data Access & Devices → Any Distance and make sure everything is enabled.")
                        }

                        Button {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                            presentationMode.dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)

                                Text("Open Settings")
                                    .foregroundColor(.black)
                                    .semibold()
                            }
                            .frame(height: 56)
                            .maxWidth(.infinity)
                        }
                    }
                    .padding([.leading, .trailing], 20)
                    .padding(.top, 16)
                }
                .frame(height: 620)
            }
            .background(Color.black.ignoresSafeArea().padding(.top, 30))
        }
        .background(Color.clear)
    }
}

struct RecordingHealthKitAuthorizationView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingHealthKitAuthorizationView()
    }
}

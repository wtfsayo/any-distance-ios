// Licensed under the Any Distance Source-Available License
//
//  AndiAppleHealthPermissionsView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/30/23.
//

import SwiftUI

/// An Apple Health permissions prompt that shows an image of Andi showing the user how to grant
/// permissions
struct AndiAppleHealthPermissionsView: View {
    var nextAction: (() -> Void)?

    var body: some View {
        VStack {
            Spacer()
            ZStack {
                Image("andi-health")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .offset(y: -120.0)
                    .overlay {
                        LinearGradient(colors: [.clear, .black],
                                       startPoint: UnitPoint(x: 0.5, y: 0.1),
                                       endPoint: UnitPoint(x: 0.5, y: 0.5))
                    }

                VStack(spacing: 16) {
                    Spacer()
                        .frame(height: 190.0)
                    Text("Apple Health is the most secure\nway to store your activity data.")
                        .multilineTextAlignment(.center)

                    Text("We read your past workout data \nto see your progress, and write new\ndata when you track an activity.")
                        .multilineTextAlignment(.center)

                    VStack(spacing: 2.0) {
                        HStack(spacing: 3.0) {
                            Text("Tap")
                            Text("Turn On All")
                                .fontWeight(.bold)
                            Text("and")
                            Text("Allow")
                                .fontWeight(.bold)
                        }
                        Text("on the next screen to get set up.")
                    }
                    .padding(.bottom, 8)

                    ADWhiteButton(title: "Continue", action: nextAction)
                        .padding([.leading, .trailing], 30)
                        .padding(.bottom, 16)
                }
                .foregroundColor(.white)
                .font(.system(size: 15.0))
            }
            .background {
                Rectangle()
                    .fill(Color.black)
                    .cornerRadius(32, corners: [.topLeft, .topRight])
                    .ignoresSafeArea()
            }
        }
    }
}

struct AndiAppleHealthPermissionsView_Previews: PreviewProvider {
    static var previews: some View {
        AndiAppleHealthPermissionsView()
            .background(Color.white)
    }
}

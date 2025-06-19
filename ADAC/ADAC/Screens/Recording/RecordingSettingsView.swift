// Licensed under the Any Distance Source-Available License
//
//  RecordingSettingsView.swift
//  ADAC
//
//  Created by Any Distance on 8/2/22.
//

import SwiftUI

struct RecordingSettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Spacer()
                .onTapGesture {
                    presentationMode.dismiss()
                }
            
            VStack {
                NavBar(title: "Settings", closeTitle: "Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .cornerRadius([.topLeading, .topTrailing], 12)
                
                PrivacyRecordingSettings()
                .padding(.top, 12)

                AutoLockSettings()
                .padding(.top, 12)
            }
            .background(Color.black.ignoresSafeArea().padding(.top, 30))
        }
        .background(Color.clear)
    }
}

struct RecordingSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingSettingsView()
    }
}

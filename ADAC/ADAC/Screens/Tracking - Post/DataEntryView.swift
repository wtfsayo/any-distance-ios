// Licensed under the Any Distance Source-Available License
//
//  DataEntryView.swift
//  ADAC
//
//  Created by Jarod Luebbert on 1/25/23.
//

import SwiftUI
import Introspect

struct DataEntryView: View {
    @Environment(\.presentationMode) var presentationMode
        
    @State var data: Double
    let title: String
    let description: String
    let inputTitle: String
    let confirmButtonTitle: String
    var dismissButtonTitle: String? = nil
    let unit: String
    let updateDataHandler: (Double) -> ()

    var body: some View {
        VStack {
            Spacer()
                .onTapGesture {
                    presentationMode.dismiss()
                }
            
            VStack {
                NavBar(title: title, closeTitle: "")
                    .cornerRadius([.topLeft, .topRight], 12)
                
                VStack {
                    Text(description)
                        .font(.system(size: 16, weight: .regular, design: .default))
                        .foregroundColor(.white)
                        .padding(.top, 8)
                    
                    DataEntryCell(title: inputTitle,
                                  data: $data)
                    
                    Button {
                        updateDataHandler(data)
                        presentationMode.dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                            Text(confirmButtonTitle)
                                .foregroundColor(.black)
                                .font(.system(size: 17, weight: .medium, design: .default))
                        }
                    }
                    .frame(height: 55)
                    .padding(.bottom, dismissButtonTitle == nil ? 25 : 0)
                    
                    if let dismissButtonTitle = dismissButtonTitle {
                        Button {
                            presentationMode.dismiss()
                        } label: {
                            Text(dismissButtonTitle)
                                .foregroundColor(.white)
                                .font(.system(size: 17, weight: .medium, design: .default))
                        }
                        .frame(height: 55)
                        .padding(.bottom, 25)
                    }
                }
                .padding([.leading, .trailing], 20)
            }
            .background(Color.black.ignoresSafeArea().padding(.top, 30))
        }
        .background(Color.clear)
    }
}


// Licensed under the Any Distance Source-Available License
//
//  GearSelectView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/21/24.
//

import SwiftUI

struct GearSelectView: View {
    var selectedGearID: String?
    var onSelect: ((String?) -> Void)
    @Environment(\.presentationMode) private var presentationMode
    @State private var isPresented: Bool = true

    func dismiss() {
        isPresented = false
        presentationMode.dismiss()
    }

    var gearCells: some View {
        Group {
            GearSelectCell(gearID: nil,
                           distanceInSelectedUnit: 0.0,
                           gearColor: nil,
                           gearName: "None",
                           formattedDate: "",
                           selectedGearID: selectedGearID,
                           onSelect: onSelect,
                           dismissAction: dismiss)
            .padding([.leading, .trailing], 15.0)

            ForEach(ADUser.current.gear, id: \.id) { gear in
                GearSelectCell(gearID: gear.id,
                               distanceInSelectedUnit: gear.distanceInSelectedUnit,
                               gearColor: gear.color,
                               gearName: gear.name,
                               formattedDate: gear.formattedDate,
                               selectedGearID: selectedGearID,
                               onSelect: onSelect,
                               dismissAction: dismiss)
                .padding([.leading, .trailing], 15.0)
            }

            Spacer()
                .frame(height: 16.0)
        }
    }

    var body: some View {
        ZStack {
            BlurView(style: .systemUltraThinMaterialDark,
                     intensity: 0.55,
                     animatesIn: true,
                     animateOut: !isPresented)
            .padding(.top, -1500)
            .ignoresSafeArea()
            .onTapGesture {
                isPresented = false
                presentationMode.dismiss()
            }

            VStack {
                Spacer()

                VStack {
                    ZStack {
                        Text("Select Shoes")
                            .font(.presicav(size: 17))
                            .opacity(0.4)
                            .multilineTextAlignment(.center)

                        HStack {
                            Spacer()
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: .xmarkCircleFill)
                                    .font(.system(size: 20.0, weight: .medium))
                                    .padding()
                                    .contentShape(Rectangle())
                                    .foregroundColor(.white)
                            }
                            .offset(x: 10.0)
                            .modifier(BlurOpacityTransition(speed: 2.0))
                        }
                        .padding([.leading, .trailing], 10.0)
                    }

                    if ADUser.current.gear.count <= 4 {
                        gearCells
                    } else {
                        ScrollView {
                            gearCells
                        }
                        .frame(height: UIScreen.main.bounds.height / 2)
                    }
                }
                .maxWidth(10000)
                .background {
                    Color(white: 0.05)
                        .cornerRadius(24.0, corners: [.topLeft, .topRight])
                        .ignoresSafeArea()
                }
            }
        }
    }
}

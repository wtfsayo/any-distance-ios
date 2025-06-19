// Licensed under the Any Distance Source-Available License
//
//  GearCells.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/23/24.
//

import SwiftUI

struct GearCell: View {
    @StateObject var user: ADUser = .current
    @ObservedObject var gear: Gear
    @Binding var gearForDetail: Gear?

    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button {
            feedbackGenerator.impactOccurred()
            gearForDetail = gear
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18.0)
                    .foregroundColor(.white)
                    .opacity(0.1)
                HStack(spacing: 6.0) {
                    ZStack {
                        Gear3DSwiftUIView(usdzName: "sneaker",
                                          color: gear.color)
                        .frame(width: 56.0, height: 46.0)
                        .allowsHitTesting(false)
                        .offset(y: -2)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(
                            String(gear.distanceInSelectedUnit.rounded(toPlaces: 1)) +
                            user.distanceUnit.abbreviation.lowercased()
                        )
                        .font(.presicav(size: 19))
                        .id(gear.distanceInSelectedUnit)
                        .modifier(BlurOpacityTransition(speed: 1.8))

                        Text(gear.name.isEmpty ? "Shoes" : gear.name)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .opacity(0.6)
                            .id(gear.formattedDate)
                            .modifier(BlurOpacityTransition(speed: 1.8))
                    }
                    .offset(y: -2.0)

                    Spacer()
                }
                .padding()
            }
        }
        .buttonStyle(ScalingPressButtonStyle())
    }
}

struct GearHorizontalCell: View {
    @StateObject var user: ADUser = .current
    @ObservedObject var gear: Gear
    @Binding var gearForDetail: Gear?

    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button {
            feedbackGenerator.impactOccurred()
            gearForDetail = gear
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18.0)
                    .foregroundColor(.white)
                    .opacity(0.1)
                VStack(spacing: 0.0) {
                    Gear3DSwiftUIView(usdzName: "sneaker",
                                      color: gear.color)
                        .frame(width: 96.0, height: 76.0)
                        .allowsHitTesting(false)
                        .padding(.top, -12.0)
                    Text(
                        String(gear.distanceInSelectedUnit.rounded(toPlaces: 1)) +
                        user.distanceUnit.abbreviation.lowercased()
                    )
                        .font(.presicav(size: 19))
                        .minimumScaleFactor(0.5)
                        .maxWidth(120.0)
                        .id(gear.distanceInSelectedUnit)
                        .modifier(BlurOpacityTransition(speed: 1.8))

                    Text(gear.name.isEmpty ? "Shoes" : gear.name)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .opacity(0.6)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(height: 30.0)
                        .maxWidth(130.0)
                }
                .padding(.top)
                .padding(.bottom, 10.0)
            }
            .frame(width: 160)
        }
        .buttonStyle(ScalingPressButtonStyle())
    }
}

struct GearSelectCell: View {
    var gearID: String?
    var distanceInSelectedUnit: Float
    var gearColor: GearColor?
    var gearName: String
    var formattedDate: String
    var selectedGearID: String?
    var onSelect: ((String?) -> Void)
    var dismissAction: () -> Void

    @StateObject private var user: ADUser = .current
    let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button {
            feedbackGenerator.impactOccurred()
            onSelect(gearID)
            dismissAction()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18.0)
                    .foregroundColor(.white)
                    .opacity(0.1)
                    .if(gearID == selectedGearID) { view in
                        view.overlay {
                            RoundedRectangle(cornerRadius: 18.0)
                                .stroke(Color.white, lineWidth: 2.0)
                        }
                    }
                HStack(spacing: 6.0) {
                    if let gearColor = gearColor {
                        Gear3DSwiftUIView(usdzName: "sneaker",
                                          color: gearColor)
                        .frame(width: 56.0, height: 46.0)
                        .allowsHitTesting(false)
                        .offset(y: -2)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(
                                String(distanceInSelectedUnit.rounded(toPlaces: 1)) +
                                user.distanceUnit.abbreviation.lowercased()
                            )
                            .font(.presicav(size: 19))
                            .id(distanceInSelectedUnit)
                            .modifier(BlurOpacityTransition(speed: 1.8))

                            Text(gearName.isEmpty ? "Shoes" : gearName)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .opacity(0.6)
                                .id(formattedDate)
                                .modifier(BlurOpacityTransition(speed: 1.8))
                        }
                        .offset(y: -2.0)
                    } else {
                        Image(systemName: .circleSlash)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 56.0, height: 46.0)
                            .opacity(selectedGearID == nil ? 0.6 : 0.3)
                            .scaleEffect(0.75)

                        Text("None")
                            .font(.presicav(size: 19))
                    }

                    Spacer()

                    if gearID == selectedGearID {
                        Image(systemName: .checkmarkCircleFill)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Color.white)
                    }
                }
                .padding()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .buttonStyle(ScalingPressButtonStyle())
    }
}

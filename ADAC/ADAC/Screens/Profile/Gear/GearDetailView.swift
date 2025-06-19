// Licensed under the Any Distance Source-Available License
//
//  GearDetailView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 3/19/24.
//

import SwiftUI
import SwiftUIX

fileprivate struct SuffixFloatTextField: View {
    @Binding var value: Float
    var suffix: String

    @State private var isEditing: Bool = false
    @State private var hasEdited: Bool = false
    @State private var placeholder: String = ""

    var body: some View {
        ZStack {
            let text = Binding<String>(
                get: {
                    var roundedValue: String {
                        if value == floor(value) {
                            return "\(Int(value))"
                        }
                        return "\(value.rounded(toPlaces: 1))"
                    }
                    if isEditing {
                        if !hasEdited {
                            return ""
                        }

                        return roundedValue
                    }

                    if value == 0 {
                        return ""
                    }

                    return "\(roundedValue)\(suffix)"
                },
                set: { text in
                    if isEditing {
                        value = Float(text) ?? value
                    }
                }
            )

            TextField(placeholder, text: text, isEditing: $isEditing)
                .disableAutocorrection(true)
                .font(Font.custom("NeueMatic Compressed", size: 90.0))
                .kerning(3)
                .onChange(of: isEditing) { newValue in
                    if newValue == false {
                        hasEdited = false
                        placeholder = "0\(suffix)"
                    } else {
                        placeholder = ""
                    }
                }
        }
        .onAppear {
            placeholder = "0\(suffix)"
        }
    }
}

struct GearColorPicker: View {
    @ObservedObject var gear: Gear

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0.0) {
                    ForEach(GearColor.allCases, id: \.rawValue) { color in
                        Button {
                            gear.color = color
                            feedbackGenerator.impactOccurred()
                        } label: {
                            Circle()
                                .foregroundColor(Color(uiColor: color.mainColor))
                                .frame(width: 36.0, height: 36.0)
                                .overlay {
                                    ZStack {
                                        Circle()
                                            .foregroundColor(Color(uiColor: color.accent1))
                                            .mask {
                                                Rectangle()
                                                    .padding(.leading, 18.0)
                                            }

                                        Rectangle()
                                            .foregroundColor(Color.black)
                                            .frame(width: 1.0, height: 36.0)
                                    }
                                }
                                .overlay {
                                    Circle()
                                        .foregroundColor(Color(uiColor: color.accent2))
                                        .frame(width: 26.0, height: 26.0)
                                        .overlay {
                                            ZStack {
                                                Circle()
                                                    .foregroundColor(Color(uiColor: color.accent3))
                                                    .mask {
                                                        Rectangle()
                                                            .padding(.leading, 13.0)
                                                    }

                                                Rectangle()
                                                    .foregroundColor(Color.black)
                                                    .frame(width: 1.0, height: 26.0)

                                                Circle()
                                                    .stroke(Color.black, lineWidth: 1.0)
                                            }
                                        }
                                }
                                .overlay {
                                    Circle()
                                        .foregroundColor(Color(uiColor: color.accent4))
                                        .frame(width: 10.0, height: 10.0)
                                        .overlay {
                                            Circle()
                                                .stroke(Color.black, lineWidth: 1.0)
                                        }
                                }
                                .overlay {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                        .opacity(gear.color == color ? 1.0 : 0.0)
                                        .animation(.easeInOut(duration: 0.1), value: gear.color)
                                }
                                .scaleEffect(gear.color == color ? 1.0 : 0.8)
                                .animation(.easeInOut(duration: 0.1), value: gear.color)
                                .padding([.leading, .trailing], 4.0)
                                .padding([.top, .bottom], 4.0)
                                .contentShape(Rectangle())
                                .drawingGroup()
                        }
                        .id(color.rawValue)
                        .buttonStyle(ScalingPressButtonStyle())
                    }
                }
                .padding([.leading, .trailing], 15.0)
            }
            .onAppear {
                proxy.scrollTo(gear.color.rawValue, anchor: .center)
            }
        }
    }
}

struct GearEditFields: View {
    @ObservedObject var gear: Gear
    @Binding var distanceInSelectedUnit: Float
    @Binding var hoursTracked: Float
    @FocusState var focusItem: Bool
    var editAnimation: Namespace.ID

    var body: some View {
        GearColorPicker(gear: gear)
            .padding([.leading, .trailing], -15.0)
            .padding(.bottom, 24.0)
            .modifier(BlurOpacityTransition(speed: 2.4))

        HStack(spacing: 12.0) {
            TextField("New shoes", text: $gear.name)
                .focused($focusItem)
                .padding([.leading, .trailing], 14.0)
                .padding([.top, .bottom], 8.0)
                .tint(.adOrangeLighter)
                .font(.system(size: 16.0))
                .modifier(EditingAnimationBorder(cornerRadius: 50.0,
                                                 opacity: 0.3))

            HStack {
                Text(gear.formattedDate)
                    .font(.system(size: 16.0))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: .chevronRight)
                    .font(.system(size: 13.0, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding([.top, .bottom], 8.0)
            .padding([.leading, .trailing], 18.0)
            .modifier(EditingAnimationBorder(cornerRadius: 50.0,
                                             opacity: 0.3))
            .overlay {
                Text("COMMISSIONED ON")
                    .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                    .offset(y: -30.0)
                    .opacity(0.5)
                    .modifier(BlurOpacityTransition(speed: 2.0))
            }
            .background(Color(white: 0.05))
            .overlay {
                DatePicker(selection: $gear.startDate,
                           displayedComponents: .date) {}
                    .opacity(0.011)
                    .scaleEffect(x: 1.4, anchor: .trailing)
                    .focused($focusItem)
                    .tint(.adOrangeLighter)
            }
        }
        .modifier(BlurOpacityTransition(speed: 2.0))

        Text("Distance and time are automatically tracked with your activities. Add starting values below (optional).")
            .font(.system(size: 14.0))
            .opacity(0.5)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .modifier(BlurOpacityTransition(speed: 2.0))

        HStack(spacing: 12.0) {
            VStack {
                SuffixFloatTextField(value: $distanceInSelectedUnit,
                                     suffix: ADUser.current.distanceUnit.abbreviation)
                .keyboardType(.decimalPad)
                .focused($focusItem)
                .multilineTextAlignment(.center)
                .tint(.adOrangeLighter)
                .modifier(EditingAnimationBorder(cornerRadius: 20.0,
                                                 opacity: 0.3))
                .matchedGeometryEffect(id: "distanceField", in: editAnimation, anchor: .center)

                Text("DISTANCE TRACKED")
                    .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                    .opacity(0.5)
                    .matchedGeometryEffect(id: "distanceLabel", in: editAnimation)
            }

            VStack {
                SuffixFloatTextField(value: $hoursTracked,
                                     suffix: "hr")
                .keyboardType(.decimalPad)
                .focused($focusItem)
                .multilineTextAlignment(.center)
                .tint(.adOrangeLighter)
                .modifier(EditingAnimationBorder(cornerRadius: 20.0,
                                                 opacity: 0.3))
                .matchedGeometryEffect(id: "timeField", in: editAnimation, anchor: .center)

                Text("TIME TRACKED")
                    .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                    .opacity(0.5)
                    .matchedGeometryEffect(id: "timeLabel", in: editAnimation)
            }
        }
        .padding(.bottom, 8.0)
    }
}

struct GearDisplayFields: View {
    @ObservedObject var gear: Gear
    @Binding var distanceInSelectedUnit: Float
    @Binding var hoursTracked: Float
    var editAnimation: Namespace.ID

    var body: some View {
        VStack(spacing: 6.0) {
            Text(gear.name.isEmpty ? "Shoes" : gear.name)
                .font(.greedMedium(size: 22.0))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            HStack(spacing: 8.0) {
                Text("Since")
                    .modifier(BlurOpacityTransition(speed: 2.0))
                Text(gear.formattedDate)
            }
            .font(.system(size: 12.0, weight: .medium, design: .monospaced))
            .foregroundColor(.white)
            .opacity(0.5)
        }
        .modifier(BlurOpacityTransition(speed: 2.0))
        .padding(.bottom, 8.0)

        HStack(spacing: 12.0) {
            VStack {
                var formattedValue: String {
                    if distanceInSelectedUnit == floor(distanceInSelectedUnit) {
                        return "\(Int(distanceInSelectedUnit))"
                    }
                    return "\(distanceInSelectedUnit.rounded(toPlaces: 1))"
                }

                HStack(spacing: 0.0) {
                    Spacer()
                    Text(formattedValue + ADUser.current.distanceUnit.abbreviation)
                        .font(Font.custom("NeueMatic Compressed", size: 90.0))
                        .foregroundColor(.white)
                        .kerning(3)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .background {
                    Color.black
                        .cornerRadius(20.0, style: .continuous)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20.0)
                                .stroke(Color(white: 0.1), lineWidth: 2.0)
                        }
                        .modifier(BlurOpacityTransition(speed: 2.0))
                }
                .matchedGeometryEffect(id: "distanceField", in: editAnimation, anchor: .center)
                .padding(.bottom, 6.0)

                Text("DISTANCE TRACKED")
                    .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                    .opacity(0.5)
                    .matchedGeometryEffect(id: "distanceLabel", in: editAnimation)
            }
            .padding(.bottom, 10.0)

            VStack {
                var formattedValue: String {
                    if hoursTracked == floor(hoursTracked) {
                        return "\(Int(hoursTracked))"
                    }
                    return "\(hoursTracked.rounded(toPlaces: 1))"
                }

                HStack(spacing: 0.0) {
                    Spacer()
                    Text(formattedValue + "hr")
                        .font(Font.custom("NeueMatic Compressed", size: 90.0))
                        .foregroundColor(.white)
                        .kerning(3)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .background {
                    Color.black
                        .cornerRadius(20.0, style: .continuous)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20.0)
                                .stroke(Color(white: 0.1), lineWidth: 2.0)
                        }
                        .modifier(BlurOpacityTransition(speed: 2.0))
                }
                .matchedGeometryEffect(id: "timeField", in: editAnimation, anchor: .center)
                .padding(.bottom, 6.0)

                Text("TIME TRACKED")
                    .font(.system(size: 12.0, weight: .medium, design: .monospaced))
                    .opacity(0.5)
                    .matchedGeometryEffect(id: "timeLabel", in: editAnimation)
            }
            .padding(.bottom, 10.0)
        }
    }
}

struct GearDetailView: View {
    @ObservedObject var gear: Gear
    var showsEdit: Bool = true
    @State var isEditing: Bool = false

    @Environment(\.presentationMode) private var presentationMode
    @FocusState private var focusItem: Bool
    @Namespace private var editAnimation
    @State private var isPresented: Bool = true
    @State private var distanceInSelectedUnit: Float = 0.0
    @State private var hoursTracked: Float = 0.0
    @State private var showingDeleteAlert: Bool = false

    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    func createGear() {
        feedbackGenerator.impactOccurred()
        ADUser.current.gear.append(gear)
        if ADUser.current.gear.count == 1 {
            NSUbiquitousKeyValueStore.default.selectedGearForTypes[.shoes] = gear.id
        }
        isEditing = false
    }

    func deleteGear() {
        let gearID = gear.id
        ADUser.current.gear.removeAll(where: { $0.id == gearID })
        if NSUbiquitousKeyValueStore.default.selectedGearForTypes[.shoes] == gearID {
            NSUbiquitousKeyValueStore.default.selectedGearForTypes[.shoes] = nil
        }

        for key in NSUbiquitousKeyValueStore.default.activityIDGearIDMap.keys {
            NSUbiquitousKeyValueStore.default.activityIDGearIDMap[key]?.removeAll(where: { $0 == gearID })
        }

        isPresented = false
        presentationMode.dismiss()
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

                VStack(alignment: .center, spacing: 12.0) {
                    HStack {
                        Text(isEditing ? (gear.isNew ? "New Shoes" : "Edit Shoes") : "")
                            .font(.presicav(size: 17))
                            .opacity(0.4)
                            .multilineTextAlignment(.center)
                            .id(isEditing || gear.isNew)
                            .modifier(BlurOpacityTransition(speed: 2.0))
                    }
                    .frame(height: 35.0)
                    .maxWidth(100000)
                    .overlay {
                        HStack {
                            if !isEditing && !gear.isNew && showsEdit {
                                Button {
                                    isEditing = true
                                    feedbackGenerator.impactOccurred()
                                } label: {
                                    Text("Edit")
                                        .font(.system(size: 15.0, weight: .medium))
                                        .padding(6.0)
                                        .contentShape(Rectangle())
                                }
                                .modifier(BlurOpacityTransition(speed: 2.0))
                            }

                            Spacer()

                            if isEditing && !gear.isNew {
                                Button {
                                    showingDeleteAlert = true
                                } label: {
                                    Text("Delete")
                                        .font(.system(size: 15.0, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(6.0)
                                        .contentShape(Rectangle())
                                }
                                .modifier(BlurOpacityTransition(speed: 2.0))
                            } else {
                                Button {
                                    isPresented = false
                                    presentationMode.dismiss()
                                } label: {
                                    Image(systemName: .xmarkCircleFill)
                                        .font(.system(size: 20.0, weight: .medium))
                                        .padding()
                                        .contentShape(Rectangle())
                                }
                                .offset(x: 10.0)
                                .modifier(BlurOpacityTransition(speed: 2.0))
                            }
                        }
                        .foregroundColor(.white)
                    }

                    Gear3DSwiftUIView(usdzName: "sneaker",
                                      color: gear.color)
                    .frame(height: 190.0)
                    .padding(.top, -25.0)
                    .padding(.bottom, -16.0)
                    .allowsHitTesting(false)

                    if isEditing {
                        GearEditFields(gear: gear,
                                       distanceInSelectedUnit: $distanceInSelectedUnit,
                                       hoursTracked: $hoursTracked,
                                       focusItem: _focusItem,
                                       editAnimation: editAnimation)
                    } else {
                        GearDisplayFields(gear: gear,
                                          distanceInSelectedUnit: $distanceInSelectedUnit,
                                          hoursTracked: $hoursTracked,
                                          editAnimation: editAnimation)
                    }

                    if gear.isNew {
                        ADWhiteButton(title: "Create \(gear.type.rawValue.capitalized)") {
                            createGear()
                        }
                        .modifier(BlurOpacityTransition(speed: 2.0))
                    } else if isEditing {
                        ADWhiteButton(title: "Save \(gear.type.rawValue.capitalized)") {
                            feedbackGenerator.impactOccurred()
                            isEditing = false
                        }
                        .modifier(BlurOpacityTransition(speed: 2.0))
                    }
                }
                .padding(15.0)
                .maxWidth(100000)
                .background {
                    Color(white: 0.05)
                        .cornerRadius(24.0, corners: [.topLeft, .topRight])
                        .ignoresSafeArea()
                        .onTapGesture {
                            focusItem = false
                        }
                }
                .transformEffect(.identity)
                .animation(.timingCurve(0.42, 0.27, 0.34, 0.96, duration: 0.3), value: isEditing)
                .animation(.timingCurve(0.42, 0.27, 0.34, 0.96, duration: 0.3), value: gear.isNew)
            }
        }
        .onAppear {
            distanceInSelectedUnit = gear.distanceInSelectedUnit
            hoursTracked = Float(gear.timeTracked) / 3600
        }
        .onChange(of: distanceInSelectedUnit) { newValue in
            gear.distanceTrackedMeters = UnitConverter.value(newValue, 
                                                             inUnitToMeters: ADUser.current.distanceUnit)
        }
        .onChange(of: hoursTracked) { newValue in
            gear.timeTracked = TimeInterval(newValue) * 3600
        }
        .alert("Are you sure you want to delete this forever?", isPresented: $showingDeleteAlert) {
            Button("Yes, Delete", role: .destructive) {
                showingDeleteAlert = false
                deleteGear()
            }
            Button("No, Cancel", role: .cancel, action: {})
        }
    }
}

#Preview {
    GearDetailView(gear: Gear(type: .shoes, name: ""))
}

// Licensed under the Any Distance Source-Available License
//
//  ARViewer.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/17/22.
//

import SwiftUI
import ARKit
import Combine

struct SwiftUIARSCNView<ARView: ADARView>: UIViewRepresentable {
    typealias UIViewType = ARView

    weak var view: ARView?

    init(_ inputView: ARView?) {
        view = inputView
    }

    func makeUIView(context: Context) -> ARView {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            Permissions.shared.camera = AVCaptureDevice.authorizationStatus(for: .video)
            if let config = view?.worldTrackingConfiguration() {
                view?.session.run(config)
            }
        }
        return view ?? ARView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

private struct SwitcherButton: View {
    var label: String
    var isSelected: Bool
    var selectionAction: () -> Void
    let generator = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        Button {
            selectionAction()
            generator.impactOccurred()
        } label: {
            ZStack {
                Group {
                    if isSelected {
                        Color.white
                    } else {
                        BlurView(style: .systemThinMaterialDark)
                    }
                }
                .mask(RoundedRectangle(cornerRadius: 40))

                Text(label)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(isSelected ? .black : .white)
                    .padding([.top, .bottom], 9)
                    .padding([.leading, .trailing], 13)
                    .fixedSize()
            }
        }
    }
}

struct ARControls<ARView: ADARView>: View {
    var model: ARViewModel<ARView>
    @ObservedObject var generatingModel: GeneratingVisualsViewModel
    @State var isRecording = false
    @State var flash = false
    @State var flashTimer: Timer?
    @State var routeType: ARRouteType = .route
    @State var medalViewMode: MedalARViewMode = .wear
    @State var showSuperDistanceView: Bool = false

    var body: some View {
        ZStack {
            VStack {
                HStack {
                    Button {
                        model.closeAction()
                    } label: {
                        ZStack {
                            BlurView(style: .systemThinMaterialDark)
                                .mask(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            Image(systemName: .xmark)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(width: 50, height: 40)
                    Spacer()
                }
                .opacity(isRecording ? 0 : 1)
                .animation(.linear(duration: 0.3), value: isRecording)

                Spacer()
                    .overlay {
                        if model.shouldShowLockedState {
                            Image(uiImage: UIImage(named: "glyph_superdistance_white")!)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: UIScreen.main.bounds.width - 32)
                                .opacity(0.5)
                                .allowsHitTesting(false)
                                .scaleEffect(0.8)
                        } else {
                            EmptyView()
                        }
                    }

                if model.controller?.showsRouteControls ?? false {
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        SwitcherButton(label: ARRouteType.route.displayName,
                                       isSelected: routeType == .route) {
                            routeType = .route
                        }
                        SwitcherButton(label: ARRouteType.routePlusStats.displayName,
                                       isSelected: routeType == .routePlusStats) {
                            routeType = .routePlusStats
                        }
                        SwitcherButton(label: ARRouteType.fullLayout.displayName,
                                       isSelected: routeType == .fullLayout) {
                            routeType = .fullLayout
                        }
                        Spacer()
                    }
                    .height(35)
                    .padding(.bottom, 20)
                    .opacity(isRecording ? 0 : 1)
                    .animation(.linear(duration: 0.3), value: isRecording)
                    .zIndex(1)
                }

                if model.controller?.showsWearableControls ?? false {
                    HStack(alignment: .center, spacing: 8) {
                        Spacer()
                        SwitcherButton(label: MedalARViewMode.place.displayName,
                                       isSelected: medalViewMode == .place) {
                            medalViewMode = .place
                        }
                        .frame(width: 100)
                        SwitcherButton(label: MedalARViewMode.wear.displayName,
                                       isSelected: medalViewMode == .wear) {
                            medalViewMode = .wear
                        }
                        .frame(width: 100)
                        Spacer()
                    }
                    .height(35)
                    .padding(.bottom, 20)
                    .opacity(isRecording ? 0 : 1)
                    .animation(.linear(duration: 0.3), value: isRecording)
                    .zIndex(1)
                }

                if model.controller?.showsRecordingControls ?? false {
                    ZStack {
                        if generatingModel.isLoading {
                            ProgressView()
                        } else {
                            Circle()
                        }
                    }
                    .frame(width: 70, height: 70)
                    .foregroundColor(isRecording ? .red : .white)
                    .scaleEffect(isRecording ? 0.95 : 1)
                    .opacity(isRecording ? (flash ? 0 : 1) : 1)
                    .animation(.linear(duration: 0.3))
                    .overlay(
                        TappableView(onTap: {
                            if model.shouldShowLockedState {
                                showSuperDistanceView = true
                                return
                            }

                            guard !generatingModel.isLoading else {
                                return
                            }

                            generatingModel.isLoading = true
                            model.takePhotoAction {
                                generatingModel.isLoading = false
                            }
                        }, onPress: { pressed in
                            if model.shouldShowLockedState {
                                return
                            }

                            guard !generatingModel.isLoading else {
                                return
                            }

                            isRecording = pressed
                        }, pressDuration: 0.4, shouldRecognizeSimultaneously: false)
                    )
                    .padding(5)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                    )
                    .padding([.bottom], 15)
                    .zIndex(2)
                    .overlay {
                        if model.shouldShowLockedState {
                            Image(uiImage: UIImage(named: "glyph_lock")!)
                                .allowsHitTesting(false)
                                .offset(x: 0, y: -5)
                        } else {
                            EmptyView()
                                .allowsHitTesting(false)
                        }
                    }

                    ZStack {
                        Image("layout_gradient")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .padding([.leading, .trailing], -20)
                            .padding([.top, .bottom], -60)

                        HStack {
                            Image(systemName: .infoCircle)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundColor(.white)
                            Text("Tap and hold to record a video")
                                .font(.system(size: 14, weight: .semibold, design: .default))
                                .foregroundColor(.white)
                        }
                        .padding([.top, .bottom], 12)
                        .opacity(isRecording ? 0 : 0.8)
                        .animation(.linear(duration: 0.3), value: isRecording)
                    }
                    .height(30)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()

            GeneratingVisualsView(model: generatingModel)
                .ignoresSafeArea()
                .opacity(generatingModel.isLoading ? 1 : 0)
                .animation(.linear(duration: 0.2), value: generatingModel.isLoading)
        }
        .onChange(of: isRecording) { _ in
            model.controller?.feedbackGenerator.impactOccurred()
            if isRecording {
                model.controller?.startRecordingAction()
                flashTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                    withAnimation(.linear(duration: 0.8)) {
                        flash.toggle()
                    }
                }
            } else {
                flashTimer?.invalidate()
                flashTimer = nil
                generatingModel.isLoading = true
                model.controller?.stopRecordingAction {
                    generatingModel.isLoading = false
                }
            }
        }
        .onChange(of: routeType) { type in
            model.controller?.routeTypeSwitched(type)
        }
        .onChange(of: medalViewMode) { mode in
            model.controller?.medalViewModeSwitched(mode)
        }
        .fullScreenCover(isPresented: $showSuperDistanceView) {
            SuperDistanceView()
        }
    }
}

struct CameraPermissionDeniedView<ARView: ADARView>: View {
    @Environment(\.openURL) var openURL
    var model: ARViewModel<ARView>

    var body: some View {
        VStack {
            HStack {
                Button {
                    model.closeAction()
                } label: {
                    ZStack {
                        BlurView(style: .systemThinMaterialDark)
                            .mask(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Image(systemName: .xmark)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 50, height: 40)
                Spacer()
            }

            VStack {
                Spacer()
                Spacer()
                Spacer()
                Image(systemName: .videoSlash)
                    .font(.system(size: 90, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .opacity(0.15)
                Spacer()
                Spacer()

                VStack(alignment: .center, spacing: 24) {
                    Text("Camera permission denied. Tap \"Open Settings,\" turn Camera on, and come back to Any Distance.")
                        .font(.system(size: 17, weight: .medium, design: .default))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .padding([.leading, .trailing], 40)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .foregroundColor(.white)
                            Text("Open Settings")
                                .font(.system(size: 17, weight: .medium, design: .default))
                                .foregroundColor(.black)
                        }
                    }
                    .height(50)
                    .maxWidth(.infinity)
                    .padding([.leading, .trailing], 30)
                }

                Spacer()
            }
        }
        .background(Color.black)
        .padding()
    }
}

struct ARViewer<ARView: ADARView>: View {
    var model: ARViewModel<ARView>
    @ObservedObject var generatingModel: GeneratingVisualsViewModel
    @StateObject var permissions: Permissions = Permissions()

    var body: some View {
        ZStack {
            switch permissions.camera {
            case .denied, .restricted:
                CameraPermissionDeniedView(model: model)
            default:
                SwiftUIARSCNView(model.controller?.arView)
                    .ignoresSafeArea()
                    .blur(radius: model.shouldShowLockedState ? 3.0 : 0.0)
                ARControls(model: model, generatingModel: generatingModel)
            }
        }
    }
}

final class ARViewModel<ARView: ADARView>: NSObject, ObservableObject {
    weak var controller: ARViewController<ARView>?
    @Published var shouldShowLockedState: Bool = false
    private var subscribers: Set<AnyCancellable> = []

    init(controller: ARViewController<ARView>) {
        self.controller = controller
        super.init()

        iAPManager.shared.$isSubscribed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.shouldShowLockedState = !iAPManager.shared.hasSuperDistanceFeatures && self?.controller?.arView is RouteARView
            }.store(in: &subscribers)

        self.shouldShowLockedState = !iAPManager.shared.hasSuperDistanceFeatures && self.controller?.arView is RouteARView
    }

    func closeAction() { controller?.closeAction() }
    func takePhotoAction(_ completion: @escaping () -> Void) { controller?.takePhotoAction(completion) }
    func startRecordingAction() { controller?.startRecordingAction() }
    func stopRecordingAction(_ completion: @escaping () -> Void) { controller?.stopRecordingAction(completion) }
    func routeTypeSwitched(_ routeType: ARRouteType) { controller?.routeTypeSwitched(routeType) }
}

// Licensed under the Any Distance Source-Available License
//
//  SafetyMessageView.swift
//  ADAC
//
//  Created by Jarod Luebbert on 11/2/22.
//

import SwiftUI
import MessageUI
import CoreLocation

fileprivate class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    let manager = CLLocationManager()

    @Published var location: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("locationManagerDidChangeAuthorization")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("locationManager didFailWithError: \(error.localizedDescription)")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first?.coordinate
    }
}

fileprivate struct MessageView: UIViewControllerRepresentable {
    let type: SafetyMessageView.SafetyMessageType
    let activityType: ActivityType
    let goal: RecordingGoal
    let location: CLLocationCoordinate2D
    let completion: ((MessageComposeResult) -> ())
    
    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        var completion: ((MessageComposeResult) -> ())
        
        init(completion: @escaping ((MessageComposeResult) -> ())) {
            self.completion = completion
        }
        
        func messageComposeViewController(_ controller: MFMessageComposeViewController,
                                   didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true, completion: nil)
            completion(result)
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(completion: completion)
    }
    
    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(location.latitude),\(location.longitude)")!
        let composeVC = MFMessageComposeViewController()
        composeVC.modalPresentationStyle = .overCurrentContext
        switch type {
        case .startingActivity:
            composeVC.body = NSLocalizedString("\(url.absoluteString)\n\nHey! I'm about to start my \(goal.iMessageFormatted)\(activityType.displayName). This is my current location. I'll let you know when I'm done and where I am.",
                                               comment: "Body of text message for safety message sent to friends/family at the start of an activity")
        case .endingActivity:
            composeVC.body = NSLocalizedString("\(url.absoluteString)\n\nHey! I finished my \(goal.iMessageFormatted)\(activityType.displayName), this is where I ended up.",
                                               comment: "Body of text message for safety message sent to friends/family at the end of an activity")
        }
        composeVC.messageComposeDelegate = context.coordinator
        return composeVC
    }
    
    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
    
    typealias UIViewControllerType = MFMessageComposeViewController
}

struct SafetyMessageView: View {
    
    enum SafetyMessageType: String, RawRepresentable {
        case startingActivity, endingActivity
    }
    
    let type: SafetyMessageType
    let activityType: ActivityType
    let goal: RecordingGoal
    let onDismiss: (MessageComposeResult) -> ()
    
    @State var didSendMessage: Bool = false
    @State private var isShowingMessages = false
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        VStack {
            Spacer()
                .onTapGesture {
                    onDismiss(.cancelled)
                }
            
            VStack {
                NavBar(title: "Safety Message", closeTitle: didSendMessage ? "" : "Skip") {
                    onDismiss(.cancelled)
                }
                .cornerRadius([.topLeft, .topRight], 12.0)
                
                VStack {
                    
                    HStack(alignment: .top, spacing: -25.0) {
                        Image(uiImage: UIImage(named: "imessage_icon")!)
                            .resizable(true)
                            .scaledToFit()
                        Image(uiImage: activityType.glyph!)
                            .resizable(true)
                            .scaledToFit()
                            .padding([.top, .bottom], 10.0)
                    }
                    .frame(height: 100.0)
                    .padding([.top, .bottom], 20.0)
                    
                    switch type {
                    case .startingActivity:
                        Text("Send a family member or friend a message you are starting your **\(activityType.displayName)**. It will include your current location and you will be prompted again when you finish.")
                    case .endingActivity:
                        Text("Send a family member or friend a message you have finished your **\(activityType.displayName)**. It will include your current location.")
                    }
                    
                    Button(action: {
                        isShowingMessages = true
                    }, label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10.0, style: .continuous)
                                .fill(.white)
                                .frame(height: 56.0)
                            if let _ = locationManager.location {
                                Text(didSendMessage ? "Sent!" : "Send Message")
                                    .foregroundColor(.black)
                                    .font(.system(size: 17.0, weight: .semibold, design: .default))
                            } else {
                                HStack {
                                    ProgressView()
                                        .tintColor(.black)
                                        .padding(.trailing, 5.0)
                                    Text("Getting location...")
                                        .foregroundColor(.black)
                                        .font(.system(size: 17.0, weight: .semibold, design: .default))

                                }
                            }
                        }
                    })
                    .disabled(locationManager.location == nil || didSendMessage)
                    .padding(.top, 7.0)
                    
                    Button(action: {
                        UIApplication.shared.topViewController?.openUrl(withString: Links.learnMoreAboutSafetyPrompty.absoluteString)
                    }, label: Text("Learn More")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .opacity(0.6)
                        .padding([.top, .bottom], 7.0)
                    )
                }
                .padding([.leading, .trailing], 20.0)
            }
            .background(Color.black.ignoresSafeArea().padding(.top, 30.0))
        }
        .sheet(isPresented: $isShowingMessages, content: {
            if let location = locationManager.location {
                MessageView(type: type,
                            activityType: activityType,
                            goal: goal,
                            location: location) { result in
                    Analytics.logEvent("Sent Safety Message", "Safety Message View", .buttonTap, withParameters: ["type": type.rawValue])

                    if result == .sent {
                        didSendMessage = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onDismiss(result)
                    }
                }
                .ignoresSafeArea()
            }
        })
        .background(Color.clear)
        .onAppear {
            locationManager.requestLocation()
        }
    }
}

struct SafetyMessageView_Previews: PreviewProvider {
    static var previews: some View {
        SafetyMessageView(type: .startingActivity, activityType: .run, goal: RecordingGoal(type: .open, unit: .miles, target: 0.0)) { result in
            //
        }
    }
}

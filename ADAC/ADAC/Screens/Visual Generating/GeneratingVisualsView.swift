// Licensed under the Any Distance Source-Available License
//
//  LoadingView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/15/22.
//

import SwiftUI

/// SwiftUI implementation of VisualGenerating - a full screen overlay that blurs whatever is underneath
/// and displays a progress bar and loading text.
struct GeneratingVisualsView: View {
    @ObservedObject var model: GeneratingVisualsViewModel
    @State var progress: Float = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if model.blurBackground {
                    BlurView(style: .dark)
                }

                if let image = model.routeImage {
                    VStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width * 1.2, height: geo.size.height * 1.2)
                            .offset(x: geo.size.width * -0.1, y: geo.size.height * -0.1)
                            .opacity(0.1)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                VStack {
                    HStack {
                        Button("Cancel", action: model.cancelAction)
                            .font(.system(size: 17, weight: .medium, design: .default))
                            .foregroundColor(Color.white)
                            .frame(maxHeight: .infinity)
                            .frame(width: 120)
                        Spacer()
                    }
                        .padding(.top, (UIApplication.shared.keyWindow?.safeAreaInsets.top ?? 0) + 16)
                        .frame(height: 50)
                    Spacer()
                    VStack(alignment: .center, spacing: 14) {
                        Text("Generating your visuals")
                            .font(.system(size: 18, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: Color(UIColor.adOrangeLighter)))
                            .frame(width: 154)
                        Text("Tag @anydistance to get featured!")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 24) {
                        HStack(alignment: .center, spacing: 32) {
                            Button(action: model.instaAction) {
                                Image(uiImage: UIImage(named: "glyph_insta_37")!)
                            }
                            Button(action: model.twitterAction) {
                                Image(uiImage: UIImage(named: "glyph_twitter_37")!)
                            }
                        }
                        VStack(alignment: .center, spacing: 8) {
                            Text("Join the community")
                                .font(.system(size: 18, weight: .bold, design: .default))
                                .foregroundColor(.white)
                            Text("#AnyDistanceCounts")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                    }
                    .opacity(model.showBottomSection ? 1 : 0)
                    Spacer()
                        .frame(height: 60)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .onReceive(model.$progress) { p in
                if model.shouldAnimate {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.progress = p
                    }
                } else {
                    withAnimation(.none) {
                        self.progress = p
                    }
                }
            }
        }
    }
}

final class GeneratingVisualsViewModel: ObservableObject {
    @Published var shouldAnimate: Bool = true
    @Published fileprivate var progress: Float = 0.3
    @Published var showBottomSection: Bool = true
    @Published var isLoading: Bool = false
    @Published var routeImage: UIImage?
    @Published var blurBackground: Bool = false
    weak var controller: VisualGeneratingActor?

    func cancelAction() {
        controller?.cancelTapped()
    }

    func instaAction() {
        UIApplication.shared.topViewController?.openUrl(withString: Links.instagram.absoluteString)
    }

    func twitterAction() {
        UIApplication.shared.topViewController?.openUrl(withString: Links.twitter.absoluteString)
    }

    func setProgress(_ newProgress: Float, animated: Bool) {
        self.shouldAnimate = animated
        self.progress = newProgress
    }
}

struct LoadingView_Previews: PreviewProvider {
    static var previews: some View {
        GeneratingVisualsView(model: GeneratingVisualsViewModel())
    }
}

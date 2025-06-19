// Licensed under the Any Distance Source-Available License
//
//  CollectiblePostsDetailView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/6/23.
//

import SwiftUI
import SwiftUIX
import SwiftRichString

/// View that shows a 3D collectible view and a list of friend posts that earned that collectible
struct CollectiblePostsDetailView: View {
    let collectible: Collectible
    @Environment(\.dismiss) var dismiss
    @State private var scrollOffset: CGFloat = 0.0
    @State private var postCellModels: [PostCellModel] = []

    let screenName = "Posts for Collectible"

    var collectible3DView: some View {
        ZStack {
            let blur = (10.0 * (-scrollOffset / 350)).clamped(to: 0...10.0)
            let offset = -0.7 * scrollOffset

            Collectible3DSwiftUIView(collectible: collectible,
                                     earned: true,
                                     engraveInitials: false)
                .frame(width: UIScreen.main.bounds.width - 40,
                       height: UIScreen.main.bounds.width - 40)
                .padding(.top, 30)
                .blur(radius: blur)
                .offset(y: offset)
                .opacity(1.0 - (blur * 0.1))
        }
    }

    var collectibleDescription: some View {
        ZStack {
            let blur = (10.0 * (-scrollOffset / 490)).clamped(to: 0...10.0)
            let offset = -0.3 * scrollOffset

            Text(collectible.description.uppercased())
                .font(.presicav(size: 26, weight: .bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundColor(.white)
                .blur(radius: blur)
                .offset(y: offset)
                .opacity(1.0 - (blur * 0.1))
        }
    }

    var collectibleTypeDescription: some View {
        ZStack {
            let blur = (10.0 * (-scrollOffset / 510)).clamped(to: 0...10.0)
            let offset = -0.3 * scrollOffset

            Text(collectible.typeDescription)
                .font(Font.system(size: 13, design: .monospaced))
                .foregroundColor(.white)
                .opacity(0.6)
                .padding(.bottom, 8)
                .blur(radius: blur)
                .offset(y: offset)
                .opacity(1.0 - (blur * 0.1))
        }
    }

    func blurbAttributedText() -> NSAttributedString {
        let normal = Style { $0.font = UIFont.systemFont(ofSize: 15) }
        let bold = Style { $0.font = UIFont.systemFont(ofSize: 15, weight: .bold) }
        let group = StyleXML(base: normal, ["b": bold])
        let text = collectible.type.hintBlurb.set(style: group)
        var paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        text.addAttributes([.paragraphStyle: paragraphStyle],
                           range: NSRange(location: 0, length: text.length))
        return text
    }

    var collectibleBlurb: some View {
        ZStack {
            let blur = (10.0 * (-scrollOffset / 530)).clamped(to: 0...10.0)
            let offset = -0.3 * scrollOffset

            AttributedText(blurbAttributedText())
                .foregroundColor(.white)
                .lineBreakMode(.byWordWrapping)
                .padding([.leading, .trailing], 30)
                .preferredMaximumLayoutWidth(UIScreen.main.bounds.width - 40)
                .multilineTextAlignment(.center)
                .lineLimit(10)
                .blur(radius: blur)
                .offset(y: offset)
                .opacity(1.0 - (blur * 0.1))
        }
    }

    var confetti: some View {
        ZStack {
            let blur = (10.0 * (-scrollOffset / 600)).clamped(to: 0...10.0)
            ConfettiSwiftUIView(confettiColors: collectible.type.confettiColors,
                                isStarted: .constant(true))
            .allowsHitTesting(false)
            .opacity(1.0 - (blur / 10.0))
            .blur(radius: blur)
        }
    }

    var body: some View {
        ZStack {
            ReadableScrollView(offset: $scrollOffset,
                               presentedInSheet: true) {
                collectible3DView
                VStack(spacing: 6) {
                    collectibleDescription
                    collectibleTypeDescription
                    collectibleBlurb
                }

                LazyVStack(spacing: 12) {
                    ForEach(postCellModels, id: \.post.id) { model in
                        ScalingPostCellWithUsername(model: model)
                            .modifier(BlurOpacityTransition(speed: 1.5))
                    }
                    Spacer()
                }
                .padding([.leading, .trailing], 20)
                .padding(.top, 15)
            }
            .mask {
                VStack(spacing: 0) {
                    Image("layout_gradient")
                        .resizable(resizingMode: .stretch)
                        .frame(width: UIScreen.main.bounds.width, height: 80)
                    Color.black
                }
                .ignoresSafeArea()
            }

            VStack {
                Text("Achievement")
                    .font(.presicav(size: 21))
                    .foregroundColor(.white)
                    .opacity(0.6)
                    .padding(.top, 12)
                Spacer()
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss.callAsFunction()
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.white)
                            .padding()
                            .overlay(Color.black.opacity(0.01))
                    }
                }
                Spacer()
            }

            confetti
        }
        .background(Color(white: 0.05))
        .onAppear {
            postCellModels = PostCache.shared
                .friendPosts(withStartDate: PostManager.shared.thisWeekPostStartDate,
                             earning: collectible)
                .map { PostCellModel(post: $0, screenName: screenName) }
            Analytics.logEvent(screenName, screenName, .screenViewed)
        }
    }
}

struct CollectiblePostsDetailView_Previews: PreviewProvider {
    static var previews: some View {
        CollectiblePostsDetailView(collectible: Collectible(type: .activity(.mi_1), dateEarned: Date()))
    }
}

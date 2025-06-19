// Licensed under the Any Distance Source-Available License
//
//  Updates.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/4/22.
//

import SwiftUI
import SDWebImage

struct SDWebImageView: UIViewRepresentable {
    typealias UIViewType = UIImageView
    var imageUrl: URL

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imageView.sd_setImageWithFade(url: imageUrl, options: [])
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}

struct RSSCellButton: View {
    var feedItem: FeedItemDataPoint
    @Environment(\.openURL) var openURL
    @State private var pressed = false

    var body: some View {
        GeometryReader { geo in
            Group {
                ZStack {
                    SDWebImageView(imageUrl: feedItem.coverImageUrl)
                        .frame(width: geo.size.width, height: geo.size.height)
                    Image(uiImage: UIImage(named: "layout_gradient")!)
                        .resizable()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .aspectRatio(contentMode: .fill)
                    VStack {
                        Spacer()
                        HStack {
                            Text(feedItem.title)
                                .font(.presicav(size: 20, weight: .bold))
                            Spacer()
                            Image(uiImage: UIImage(named: "glyph_cell_arrow")!)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                        }
                        .padding(20)
                    }
                }
            }
            .compositingGroup()
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                TappableView(onTap: {
                    UIApplication.shared.topViewController?.openUrl(withString: feedItem.link.absoluteString)
                }, onPress: onPress, pressDuration: 0.1)
            )
            .compositingGroup()
            .opacity(pressed ? 0.6 : 1)
            .scaleEffect(pressed ? 0.95 : 1)
        }
    }

    private func onPress(isPressed: Bool) {
        withAnimation(Animation.easeInOut(duration: 0.2)) {
            self.pressed = isPressed
        }
    }
}

struct Updates: View {
    @Environment(\.presentationMode) var presentationMode

    private var feedItems: [FeedItemDataPoint] {
        return RSSParser.shared.feedItems.map(FeedItemDataPoint.init)
    }

    var body: some View {
        VStack {
            HStack {
                Text("Updates")
                    .font(.presicav(size: 18))
                    .opacity(0.4)
                Spacer()
                Button {
                    self.presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 18, weight: .medium, design: .default))
                        .foregroundColor(.white)
                }
            }
            .frame(height: 60)
            .padding([.leading, .trailing], 20)

            GeometryReader { geo in
                TappableScrollView {
                    ForEach(feedItems, id: \.id) { item in
                        RSSCellButton(feedItem: item)
                            .frame(width: geo.size.width - 40, height: 180)
                    }
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .background(
            Color(white: 0.05, opacity: 1)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct Updates_Previews: PreviewProvider {
    static var previews: some View {
        Updates()
    }
}

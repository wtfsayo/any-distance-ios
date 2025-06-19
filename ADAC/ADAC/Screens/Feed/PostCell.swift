// Licensed under the Any Distance Source-Available License
//
//  PostCell.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/28/23.
//

import SwiftUI
import SwiftUIX
import SDWebImage
import Combine

/// View that shows a table view cell for a post. Includes inline reaction picker and wheel reaction
/// picker.
struct PostCell: View {
    @StateObject var model: PostCellModel
    @State var showingReactionWheel: Bool = false
    @State var showingInlineReactions: Bool = false
    @State var inlineHeartFilled: Bool = false
    @State var showReactButton: Bool = false
    @State var touchingDown: Bool = false
    @State var isReactable: Bool = false
    @State var globalFrame: CGRect = .zero

    init(model: PostCellModel) {
        self._model = StateObject(wrappedValue: { model }())
    }

    func react(with type: PostReactionType) {
        isReactable = false
        Analytics.logEvent("Post react", model.screenName, .buttonTap)
        Task(priority: .userInitiated) {
            do {
                try await PostManager.shared.createReaction(on: model.post, with: type)
            } catch {
                DispatchQueue.main.async {
                    UIApplication.shared.topViewController?.showFailureToast(with: error)
                }
            }
        }
    }

    var cell: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.white
                    .opacity(0.01)
                    .overlay {
                        ZStack {
                            Rectangle()
                                .fill(Color.white.opacity(0.1))

                            if let url = model.post.mediaUrls.first {
                                AsyncCachedImage(url: url,
                                                 resizeToWidth: 400.0,
                                                 showsLoadingIndicator: true)
                                .opacity(0.6)
                            } else if let mapImage = model.mapRouteImage {
                                Image(uiImage: mapImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .saturation(0.0)
                                    .contrast(1.45)
                                    .brightness(0.08)
                                    .mask {
                                        Image("layout_gradient_left")
                                            .resizable(resizingMode: .stretch)
                                    }
                                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                            }
                        }
                    }
                    .clipped()
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(model.post.activityType.glyphName)
                            .resizable()
                            .frame(width: 36, height: 36)
                        Text(model.post.formattedTopMetric)
                            .font(.presicav(size: 23))
                        Spacer()

                        if let miniRouteImage = model.miniRouteImage,
                           model.mapRouteImage == nil {
                            Image(uiImage: miniRouteImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 38, height: 38)
                                .opacity(0.8)
                                .modifier(BlurOpacityTransition(speed: 1.5))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        if !model.post.title.isEmpty {
                            Text(model.post.title)
                                .font(.system(size: 20, weight: .semibold))
                        }

                        if !model.post.postDescription.isEmpty {
                            Text(model.post.tagDecodedDescription)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(6)
                                .font(.system(size: 14))
                        }
                    }
                    .padding(.bottom, -8)

                    HStack(alignment: .bottom, spacing: model.post.mediaUrls.isEmpty ? 8.0 : 4.0) {
                        if !model.post.reactions.isEmpty {
                            HStack(spacing: 4) {
                                let reactions = Array(model.post.talliedReactions.keys).sorted(by: { $0.rawValue > $1.rawValue })
                                ForEach(reactions, id: \.rawValue) { react in
                                    Text(react.emoji)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .offset(y: -0.5)
                                }
                                Text(String(model.post.reactions.count))
                                    .font(.system(size: 13, design: .monospaced))
                            }
                            .padding([.leading, .trailing], 8)
                            .padding([.top, .bottom], 6)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.black.opacity(0.4))
                            }
                            .opacity(showingInlineReactions ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.08), value: showingInlineReactions)
                            .drawingGroup()
                            .id(model.post.reactions.count)
                            .modifier(BlurOpacityTransition(speed: 2.0))
                        }

                        if !model.post.comments.isEmpty {
                            HStack(spacing: 4) {
                                LightBlurGlyph(symbolName: "message.fill", size: 11.5)
                                Text(String(model.post.comments.count))
                                    .font(.system(size: 13, design: .monospaced))
                            }
                            .padding([.leading, .trailing], 8)
                            .padding([.top, .bottom], 6)
                            .background {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.black.opacity(0.4))
                            }
                            .opacity(showingInlineReactions ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.08), value: showingInlineReactions)
                            .animation(.easeInOut(duration: 0.25), value: model.post.reactions)
                        }

                        Spacer()

                        HStack(spacing: -10) {
                            ForEach(model.post.medals, id: \.type.rawValue) { medal in
                                AsyncCachedImage(url: medal.medalImageUrl,
                                                 resizeToWidth: 50.0,
                                                 showsLoadingIndicator: false)
                                .frame(width: 25, height: 38)
                            }
                        }
                    }
                    .frame(minHeight: 28.0)
                    .padding(.leading, model.post.mediaUrls.isEmpty ? 0.0 : -2.0)
                    .padding(.leading, showReactButton ? 34.0 : 0.0)
                }
                .padding(20.0)
                .shadow(radius: 6)
            }

            if model.post.mediaUrls.count >= 2 {
                let urls = model.post.mediaUrls.dropFirst().prefix(2)
                HStack(spacing: 0) {
                    ForEach(urls, id: \.absoluteString) { url in
                        Color.white
                            .opacity(0.1)
                            .overlay {
                                AsyncCachedImage(url: url,
                                                 resizeToWidth: 400.0 / CGFloat(urls.count),
                                                 showsLoadingIndicator: true)
                                .frame(height: 180.0)
                            }
                            .clipped()
                    }
                }
                .frame(height: 180.0)
            }
        }
    }

    var inlineReactionPicker: some View {
        VStack(alignment: .leading) {
            Spacer()

            InlineReactionPicker(heartFilled: $inlineHeartFilled,
                                 showingInlineReactions: $showingInlineReactions,
                                 onReact: { type in
                self.react(with: type)
            })
            .opacity(showReactButton ? 1.0 : 0.0)
            .allowsHitTesting(isReactable)

            if model.post.mediaUrls.count >= 2 {
                Spacer()
                    .frame(height: 180.0)
            }
        }
    }

    var body: some View {
        ZStack {
            cell
                .mask {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                }
                .drawingGroup()
                .modifier(ReactionWheel(showsReactions: $isReactable,
                                        showingReactions: $showingReactionWheel,
                                        touchingDown: $touchingDown,
                                        onReact: { reaction in
                    react(with: reaction)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            self.isReactable = false
                        }
                    }
                }, onTap: {
                    guard !showingReactionWheel else {
                        return
                    }

                    Analytics.logEvent("Post tapped", model.screenName, .buttonTap)
                    UIApplication.shared.topViewController?.showPost(model.post,
                                                                     fromFrame: globalFrame)
                }))

            inlineReactionPicker
                .scaleEffect(x: touchingDown ? 0.95 : 1.0,
                             y: touchingDown ? 0.95 : 1.0)
                .opacity(touchingDown ? 0.8 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: touchingDown)
                .opacity(showingReactionWheel ? 0.0 : 1.0)
                .animation(.easeInOut(duration: 0.2).delay(showingReactionWheel ? 0.0 : 0.3),
                           value: showingReactionWheel)
        }
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(key: CGRectPreferenceKey.self,
                                value: geo.frame(in: .global))
            }
        }
        .onPreferenceChange(CGRectPreferenceKey.self) { value in
            self.globalFrame = value
        }
        .onChange(of: showingReactionWheel) { newValue in
            if newValue == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                        self.showingInlineReactions = false
                    }
                }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    self.isReactable = false
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        self.isReactable = self.model.post.isReactable
                    }
                }
            }
        }
        .onAppear {
            if model.post.creatorIsSelf {
                isReactable = false
                showReactButton = false
            } else {
                isReactable = model.post.isReactable
                inlineHeartFilled = !model.post.isReactable
                showReactButton = true
            }
            model.loadMapRouteImage()
        }
        .onDisappear {
            self.showingInlineReactions = false
        }
        .onChange(of: model.post.reactions) { _ in
            isReactable = model.post.isReactable
            inlineHeartFilled = !model.post.isReactable
        }
    }
}

/// Wrapper around PostCell that includes a row above with username, profile picture, and date
struct PostCellWithUsername: View {
    @ObservedObject var model: PostCellModel

    func showProfile(for user: ADUser) {
        Analytics.logEvent("Profile in post cell tapped", model.screenName, .buttonTap)
        let vc = UIHostingController(rootView:
            ProfileView(model: ProfileViewModel(user: user),
                        presentedInSheet: true)
                .background(Color.clear)
        )
        vc.view.backgroundColor = .clear
        vc.view.layer.backgroundColor = UIColor.clear.cgColor
        UIApplication.shared.topViewController?.present(vc, animated: true)
    }

    var body: some View {
        VStack {
            HStack {
                if let creator = model.postAuthor {
                    Button {
                        showProfile(for: creator)
                    } label: {
                        HStack {
                            UserProfileImageView(user: creator,
                                                 showsLoadingIndicator: true,
                                                 width: 30)
                            Text("@" + (creator.username ?? ""))
                                .font(.system(size: 14, weight: .medium))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .opacity(0.7)
                                .foregroundColor(.white)
                        }
                        .background(Color.black.opacity(0.01))
                    }
                }

                Spacer()

                Text(model.post.feedFormattedDate)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .opacity(0.7)
            }
            .frame(height: 55)

            PostCell(model: model)
        }
    }
}

/// Model for PostCell
class PostCellModel: NSObject, ObservableObject {
    var post: Post
    var screenName: String
    @Published var postAuthor: ADUser?
    @Published var miniRouteImage: UIImage?
    @Published var mapRouteImage: UIImage?
    private var subscribers: Set<AnyCancellable> = []

    init(post: Post, screenName: String) {
        self.post = post
        self.screenName = screenName
        super.init()
        post.objectWillChange
            .receive(on: DispatchQueue.main)
            .throttle(for: 0.1, scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscribers)

        Task(priority: .userInitiated) {
            let author = await post.author()
            await MainActor.run {
                self.postAuthor = author
            }
        }

        Task(priority: .userInitiated) {
            let image = await post.miniRouteImage
            await MainActor.run {
                self.miniRouteImage = image
            }
        }
    }

    func loadMapRouteImage() {
        Task(priority: .medium) {
            guard post.mediaUrls.isEmpty &&
                  post.activityType.showsRoute &&
                  !post.hiddenStatTypes.contains(Post.HiddenStatType.location.rawValue) else {
                return
            }

            let mapRouteImage = await post.mapRouteImage
            await MainActor.run {
                self.mapRouteImage = mapRouteImage
            }
        }
    }

    func clearMapRouteImage() {
        mapRouteImage = nil
    }
}

/// Convenience extension for Post that formats metrics for display
extension Post {
    var formattedTopMetric: String {
        if let distanceMeters = distanceMeters, distanceMeters != 0.0 {
            let distanceInUnit = UnitConverter.meters(distanceMeters,
                                                      toUnit: ADUser.current.distanceUnit)
            return String(format: "%.1f", distanceInUnit) + (ADUser.current.distanceUnit.abbreviation)
        }

        if let movingTime = movingTime {
            return movingTime.timeFormatted(includeSeconds: false,
                                            includeAbbreviations: true)
        }

        return ""
    }
}

struct PostCell_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            PostCell(model: PostCellModel(post: Post(), screenName: "Previews"))
            PostCellWithUsername(model: PostCellModel(post: Post(), screenName: "Previews"))
        }
    }
}

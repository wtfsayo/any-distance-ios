// Licensed under the Any Distance Source-Available License
//
//  RecordingInviteCodesView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 9/6/22.
//

import SwiftUI

fileprivate struct CodesTableView: View {
    static let screenName = "Invite Codes"

    @Binding var codes: [InviteCode]
    @ObservedObject var generatingModel: GeneratingVisualsViewModel

    private func copyCode(_ code: InviteCode) {
        Analytics.logEvent("Copy Code", CodesTableView.screenName, .buttonTap)
        UIPasteboard.general.string = code.code
        let model = ToastView.Model(title: "Code Copied",
                                    description: code.code,
                                    image: UIImage(systemName: "checkmark.circle.fill"),
                                    autohide: true,
                                    maxPerSession: 100)
        let toast = ToastView(model: model,
                              imageTint: .systemGreen,
                              borderTint: .systemGreen)
        let topVC = UIApplication.shared.topViewController
        topVC?.view.present(toast: toast,
                            insets: .init(top: 0, left: 0, bottom: 30, right: 0))
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(enumerating: codes, id: \.code) { idx, code in
                let type: TableViewCellType = {
                    switch idx {
                    case 0:
                        return .top
                    case codes.count - 1:
                        return .bottom
                    default:
                        return .middle
                    }
                }()

                let accessory: AnyView = {
                    if code.used {
                        return AnyView(
                            HStack {
                                Text("Used")
                                    .font(.system(size: 16, weight: .medium, design: .default))
                                Image(systemName: .checkmarkCircleFill)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.white)
                                    .opacity(0.5)
                            }
                        )
                    } else {
                        return AnyView(
                            HStack {
                                Text("Share")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                                Image(systemName: .squareAndArrowUpCircleFill)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(.white)
                                    .opacity(0.5)
                            }
                        )
                    }
                }()

                TableViewCell(text: code.code,
                              font: .system(size: 17, weight: .regular, design: .monospaced),
                              textColor: code.used ? .white : .adOrangeLighter,
                              accessory: accessory,
                              type: type) {
                    if !code.used {
                        Analytics.logEvent("Share Code Tapped", CodesTableView.screenName, .buttonTap)

                        generatingModel.showBottomSection = false
                        generatingModel.setProgress(0, animated: false)
                        generatingModel.isLoading = true
                        RecordingInviteShareVideoGenerator.renderVideos(withCode: code.code) {
                            return false
                        } progress: { p in
                            generatingModel.setProgress(p, animated: true)
                        } completion: { videos in
                            generatingModel.isLoading = false
                            if let vc = UIStoryboard(name: "Activities", bundle: nil).instantiateViewController(withIdentifier: "shareVC") as? ShareViewController {
                                vc.videos = videos
                                vc.title = "Share"
                                UIApplication.shared.topViewController?.present(vc, animated: true, completion: nil)
                            }
                        }
                    }
                }
                  .overlay {
                      HStack {
                          Color(white: 0.1).opacity(0.02)
                              .contentShape(Rectangle())
                              .frame(width: 120)
                              .frame(maxHeight: .infinity)
                              .onTapGesture {
                                  self.copyCode(code)
                              }
                              .onLongPressGesture {
                                  self.copyCode(code)
                              }
                          Spacer()
                      }
                  }
                .opacity(code.used ? 0.5 : 1)
                .allowsHitTesting(!code.used)
            }
        }
    }
}

fileprivate struct InviteCodesBody: View {
    @Binding var codes: [InviteCode]
    @ObservedObject var generatingModel: GeneratingVisualsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Invite Codes")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundColor(.white)

            Text("Thanks for being a supporter. You have early access to our new Activity Tracking experience.")
                .font(.system(size: 17, weight: .regular, design: .default))
                .foregroundColor(.white)

            Text("Want to invite your raddest friends to Early Access? Tap to share the codes below.")
                .font(.system(size: 17, weight: .regular, design: .default))
                .foregroundColor(.white)
                .padding(.bottom, 20)

            if codes.isEmpty {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white)
                        .opacity(0.1)
                    ProgressView()
                }
                .frame(height: 255)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            } else {
                CodesTableView(codes: $codes, generatingModel: generatingModel)
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
    }
}

struct RecordingInviteCodesView: View {
    @State var codes: [InviteCode] = []
    @StateObject var generatingModel: GeneratingVisualsViewModel = GeneratingVisualsViewModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    LoopingVideoView(videoUrl: Bundle.main.url(forResource: "coin",
                                                               withExtension: "mov"))
                    .frame(width: geo.size.width * 0.75, height: geo.size.width * 0.75)
                    .padding(.top, 25)

                    Spacer()
                }

                VStack {
                    EarlyAccessCloseHeader()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Spacer()
                                .frame(height: (geo.size.height - 550).clamped(to: 170...CGFloat.greatestFiniteMagnitude))
                            InviteCodesBody(codes: $codes, generatingModel: generatingModel)
                                .background {
                                    LinearGradient(colors: [.black, .black, .clear],
                                                   startPoint: UnitPoint(x: 0.5, y: 0.5),
                                                   endPoint: .top)
                                    .offset(y: -80)
                                }
                            Spacer()
                                .frame(height: 20)
                        }
                        .padding([.leading, .trailing], 20)
                    }
                    .maxWidth(.infinity)
                }

                GeneratingVisualsView(model: generatingModel)
                    .ignoresSafeArea()
                    .opacity(generatingModel.isLoading ? 1 : 0)
                    .animation(.linear(duration: 0.2), value: generatingModel.isLoading)
            }
            .onAppear {
                generatingModel.blurBackground = true
                Task(priority: .userInitiated) {
                    codes = await InviteCodeManager.shared.activityTrackingInviteCodesForUser().sorted(by: { $0.code < $1.code })
                    if codes.contains(where: { $0.used }) {
                        CollectibleManager.grantActivityTrackingEarlyAccessCollectible()
                        CloudKitUserManager.shared.saveCurrentUser()
                    }
                }
            }
        }
    }
}

struct RecordingInviteCodesView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingInviteCodesView()
            .previewDevice("iPhone 13 Pro")
    }
}

// Licensed under the Any Distance Source-Available License
//
//  InlineReactionPicker.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/15/23.
//

import SwiftUI

struct InlineReactionPicker: View {
    @Binding var heartFilled: Bool
    @Binding var showingInlineReactions: Bool
    var onReact: ((PostReactionType) -> Void)?

    @State private var selectedInlineReaction: PostReactionType? = nil
    @State private var inlineEmojiOpacityState: Bool = false

    private let notificationGenerator = UINotificationFeedbackGenerator()

    var body: some View {
        HStack {
            ZStack {
                Button {
                    showingInlineReactions = true
                } label: {
                    ZStack {
                        Image(systemName: .heartFill)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 13.0, height: 13.0)
                            .foregroundColor(.white)
                            .font(.system(size: 13.0, weight: .bold))
                            .padding()
                            .opacity(heartFilled ? 1.0 : 0.0)
                            .scaleEffect(x: heartFilled ? 1.0 : 0.1, y: heartFilled ? 1.0 : 0.1)
                            .opacity(showingInlineReactions ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: showingInlineReactions)

                        Image(systemName: .heart)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 13.0, height: 13.0)
                            .foregroundColor(.black)
                            .font(.system(size: 13.0, weight: .bold))
                            .padding()
                            .opacity(heartFilled ? 0.0 : 1.0)
                            .scaleEffect(x: heartFilled ? 0.1 : 1.0, y: heartFilled ? 0.1 : 1.0)
                            .opacity(showingInlineReactions ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.15), value: showingInlineReactions)
                    }
                    .offset(y: 0.5)
                }
                .frame(width: 28.0,
                       height: 28.0)

                HStack(spacing: 0.0) {
                    ForEach(PostReactionType.availableTypes.enumerated().map { $0 },
                            id: \.element) { (idx, type) in
                        Button {
                            selectedInlineReaction = type
                            notificationGenerator.notificationOccurred(.success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.inlineEmojiOpacityState = false

                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75).delay(0.2)) {
                                    self.showingInlineReactions = false
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        self.heartFilled = true
                                    }
                                    self.onReact?(type)
                                }

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    self.selectedInlineReaction = nil
                                }
                            }
                        } label: {
                            Text(type.emoji)
                                .font(.system(size: 17.0, design: .monospaced))
                                .contentShape(Rectangle())
                                .opacity(inlineEmojiOpacityState ? 1.0 : 0.0)
                                .scaleEffect(x: inlineEmojiOpacityState ? 1.0 : 0.5,
                                             y: inlineEmojiOpacityState ? 1.0 : 0.5)
                                .animation(.spring(response: 0.35, dampingFraction: 0.6).delay(TimeInterval(idx) * 0.05),
                                           value: inlineEmojiOpacityState)
                                .opacity(showingInlineReactions ? 1.0 : 0.0)
                                .scaleEffect(x: type == selectedInlineReaction ? 1.5 : 1.0,
                                             y: type == selectedInlineReaction ? 1.5 : 1.0)
                                .animation(.easeInOut(duration: 0.1), value: selectedInlineReaction)
                        }
                        if (idx != PostReactionType.availableTypes.count - 1) {
                            Spacer()
                        }
                    }
                }
                .padding([.leading, .trailing], 11.0)
                .frame(width: showingInlineReactions ? 200.0 : 0.0)
                .animation(.spring(response: 0.23, dampingFraction: 0.75),
                           value: showingInlineReactions)
            }
            .background {
                RoundedRectangle(cornerRadius: 20.0)
                    .foregroundColor(heartFilled ? Color.black.opacity(0.4) : .white)
                    .frame(height: showingInlineReactions ? 40.0 : 28.0)
                    .animation(.spring(response: 0.23, dampingFraction: 0.75),
                               value: showingInlineReactions)
            }
            Spacer()
        }
        .frame(height: 28.0)
        .padding(20.0)
        .onChange(of: showingInlineReactions) { newValue in
            inlineEmojiOpacityState = newValue
        }
    }
}

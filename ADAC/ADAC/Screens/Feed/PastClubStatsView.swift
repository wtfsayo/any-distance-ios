// Licensed under the Any Distance Source-Available License
//
//  PastClubStatsView.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/24/23.
//

import SwiftUI
import Combine

/// View for a cell that preivews club stats for a prior week
struct PastClubStatsCell: View {
    @StateObject var model: PastClubStatsCellModel
    var alwaysAnimate: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    let text = model.clubStats.startDate.formatted(withFormat: "MMM d") + " - " + model.clubStats.endDate.formatted(withFormat: "MMM d")
                    Text(text)
                        .font(.presicav(size: 20))
                        .foregroundColor(.white)
                }
                .padding([.leading, .trailing, .top], 20)

                ClubStats(stats: [
                    ClubStats.Item(stat: model.clubStats.data.formattedTotalDistance,
                                   label: ADUser.current.distanceUnit.abbreviation.uppercased()),
                    ClubStats.Item(stat: model.clubStats.data.formattedTime, label: "MINUTES"),
                    ClubStats.Item(stat: model.clubStats.data.formattedElevationGain,
                                   label: "\(ADUser.current.distanceUnit == .miles ? "FT" : "M") EL GAIN"),
                    ClubStats.Item(stat: "\(model.medals.count)", label: "MEDALS")
                ], fontScale: 0.9)
                .padding([.leading, .trailing], 20)
                .padding(.bottom, 6)

                if !model.uniquedMedals.isEmpty {
                    let medalWidth: CGFloat = 38
                    let medalSpacing: CGFloat = 8

                    HorizontalImageRow(imageSize: CGSize(width: medalWidth, height: medalWidth * 1.525),
                                       imageSpacing: medalSpacing,
                                       collectibles: model.uniquedMedals,
                                       alwaysAnimate: alwaysAnimate) { collectible in
                        let storyboard = UIStoryboard(name: "Collectibles", bundle: nil)
                        guard let vc = storyboard.instantiateViewController(withIdentifier: "collectibleDetail") as? CollectibleDetailViewController else {
                            return
                        }

                        vc.collectible = collectible
                        vc.collectibleEarned = ADUser.current.collectibles
                            .contains(where: { $0.type.rawValue == collectible.type.rawValue })
                        UIApplication.shared.topViewController?.present(vc, animated: true)
                    }
                                       .frame(height: medalWidth * 1.525)
                                       .mask {
                                           HStack(spacing: 0) {
                                               Image("layout_gradient_left")
                                                   .resizable(resizingMode: .stretch)
                                                   .frame(width: UIScreen.main.bounds.width * 0.1,
                                                          height: medalWidth * 1.525)
                                               Color.black
                                               Image("layout_gradient_right")
                                                   .resizable(resizingMode: .stretch)
                                                   .frame(width: UIScreen.main.bounds.width * 0.1,
                                                          height: medalWidth * 1.525)
                                           }
                                       }
                }

                Spacer()
                    .frame(height: 8)
            }
        }
        .padding([.top, .bottom], 3)
    }
}

/// Model for PastClubStatsCell
class PastClubStatsCellModel: NSObject, ObservableObject {
    var clubStats: DateRangedClubStatsData
    @Published var medals: [Collectible] = []
    @Published var uniquedMedals: [Collectible] = []
    private var subscribers: Set<AnyCancellable> = []

    init(clubStatsData: DateRangedClubStatsData) {
        self.clubStats = clubStatsData
        self.medals = clubStatsData.data.medals
        self.uniquedMedals = clubStatsData.data.uniquedMedals
        super.init()

        ADUser.current.$distanceUnit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &subscribers)
    }
}

/// Screen that shows a scrollable view of many DateRangeClubStatsData (must be wrapped in PastClubStatsCellModel's)
struct PastClubStatsView: View {
    var pastClubStatsDataModels: [PastClubStatsCellModel]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack {
                    Spacer()
                        .frame(height: 70)
                    ForEach(pastClubStatsDataModels,
                            id: \.clubStats.startDate.timeIntervalSince1970) { model in
                        PastClubStatsCell(model: model, alwaysAnimate: true)
                            .padding([.leading, .trailing], 15)
                    }
                    Spacer()
                        .frame(height: 20)
                }
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
                Text("Previous Weeks")
                    .font(.presicav(size: 18))
                    .foregroundColor(.white)
                    .opacity(0.6)
                    .padding(.top, 14)
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
        }
        .background(Color.black)
    }
}

struct PastClubStatsView_Previews: PreviewProvider {
    static var previews: some View {
        PastClubStatsView(pastClubStatsDataModels: [])
    }
}

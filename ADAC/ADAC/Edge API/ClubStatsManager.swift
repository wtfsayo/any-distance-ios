// Licensed under the Any Distance Source-Available License
//
//  ClubStatsManager.swift
//  ADAC
//
//  Created by Daniel Kuntz on 4/24/23.
//

import Foundation
import SwiftyJSON

class ClubStatsManager {
    static let shared = ClubStatsManager()
    private let baseUrl = Edge.host.appendingPathComponent("posts")

    func getPastClubStatsData() async -> [DateRangedClubStatsData] {
        guard let userSignupDate = ADUser.current.createdAt else {
            return []
        }

        let firstWeekPostStartDate: Date = {
            if Calendar.current.component(.weekday, from: userSignupDate) == 2 {
                return Calendar.current.startOfDay(for: userSignupDate)
            }

            return Calendar.current.nextDate(after: userSignupDate,
                                             matching: DateComponents(weekday: 2),
                                             matchingPolicy: .strict,
                                             direction: .backward) ?? Date()
        }()

        let thisWeekPostStartDate = PostManager.shared.thisWeekPostStartDate

        return await withTaskGroup(of: DateRangedClubStatsData?.self) { group in
            var curDate: Date = firstWeekPostStartDate
            while curDate < thisWeekPostStartDate {
                let startDate = curDate
                let endDate = Calendar.current.date(byAdding: .init(day: 7), to: startDate) ?? Date()
                group.addTask(priority: .userInitiated) {
                    if let cachedData = ClubStatsCache.shared.clubStatsData(for: startDate) {
                        let dateRangedData = DateRangedClubStatsData(startDate: startDate,
                                                                     endDate: endDate,
                                                                     data: cachedData)
                        return dateRangedData
                    }

                    if let fetchedData = try? await self.getClubStats(startDate: startDate,
                                                                      endDate: endDate) {
                        let dateRangedData = DateRangedClubStatsData(startDate: startDate,
                                                                     endDate: endDate,
                                                                     data: fetchedData)
                        return dateRangedData
                    }

                    return nil
                }
                curDate = endDate
            }

            var allData: [DateRangedClubStatsData] = []
            for await data in group {
                if let data = data {
                    allData.append(data)
                }
            }

            return allData.sorted(by: { $0.startDate > $1.startDate })
        }
    }

    func getClubStats(for userID: ADUser.ID = ADUser.current.id,
                      startDate: Date,
                      endDate: Date? = nil) async throws -> ClubStatsData {
        let url = baseUrl
            .appendingPathComponent("data-agg")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = [
            URLQueryItem(name: "id", value: userID),
            URLQueryItem(name: "startDate", value: String(UInt64(startDate.timeIntervalSince1970)))
        ]

        if let endDate = endDate {
            let item = URLQueryItem(name: "endDate", value: String(UInt64(endDate.timeIntervalSince1970)))
            components?.queryItems?.append(item)
        }

        guard let urlWithComponents = components?.url else {
            throw PostManagerError.urlEncodingError
        }
        let request = try Edge.defaultRequest(with: urlWithComponents, method: .get)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let stringData = String(data: data, encoding: .utf8)
            //            print(stringData)
            throw PostManagerError.requestError(stringData)
        }

        let json = try JSON(data: data)
        let clubStats = try json["data"].rawData()
        let clubStatsData = try JSONDecoder().decode(ClubStatsData.self, from: clubStats)
        ClubStatsCache.shared.cache(clubStats: clubStatsData, for: startDate)
        return clubStatsData
    }
}

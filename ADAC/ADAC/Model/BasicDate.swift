// Licensed under the Any Distance Source-Available License
//
//  BasicDate.swift
//  ADAC
//
//  Created by Daniel Kuntz on 5/3/22.
//

import Foundation

struct BasicDate: Codable {
    var month: Int
    var day: Int?
    var year: Int?
    
    init(month: Int, day: Int?, year: Int? = nil) {
        self.month = month
        self.day = day
        self.year = year
    }
    
    init(from date: Date) {
        let components = Calendar.current.dateComponents([.month, .day, .year], from: date)
        month = components.month ?? 1
        day = components.day
        year = components.year
    }

    func matches(_ date: Date) -> Bool {
        let components = Calendar.current.dateComponents([.month, .day, .year], from: date)
        let yearMatches = (year ?? components.year) == components.year
        let monthMatches = month == components.month
        let dayMatches = (day ?? components.day) == components.day

        return yearMatches && monthMatches && dayMatches
    }

    func endDate() -> Date {
        if year == nil {
            return Date.distantFuture
        }

        if day == nil {
            let startOfMonth = Calendar.current.date(from: DateComponents(year: year, month: month))!
            let endOfMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)
            return endOfMonth ?? Date.distantFuture
        }

        let startOfDay = Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)
        return endOfDay ?? Date.distantFuture
    }

    func swiftDate() -> Date? {
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }
}

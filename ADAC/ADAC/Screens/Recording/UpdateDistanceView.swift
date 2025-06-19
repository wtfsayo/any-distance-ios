// Licensed under the Any Distance Source-Available License
//
//  UpdateDistanceView.swift
//  ADAC
//
//  Created by Jarod Luebbert on 1/25/23.
//

import SwiftUI
import Introspect

struct UpdateDistanceView: View {
    @Environment(\.presentationMode) var presentationMode
    
    let distance: Double
    let unit: String
    let updateDistanceHandler: (Double) -> ()
    
    var body: some View {
        DataEntryView(data: distance,
                      title: "Add Distance",
                      description: "Add your distance to this activity. Your pace will be calculated based on your entry and time elapsed.",
                      inputTitle: unit.capitalized,
                      confirmButtonTitle: "Save",
                      unit: unit,
                      updateDataHandler: updateDistanceHandler)
    }
}

struct UpdateDistanceView_Previews: PreviewProvider {
    static var previews: some View {
        UpdateDistanceView(distance: 5.0, unit: "miles") { _ in }
    }
}


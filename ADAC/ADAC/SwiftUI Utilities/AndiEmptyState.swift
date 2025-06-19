// Licensed under the Any Distance Source-Available License
//
//  AndiEmptyState.swift
//  ADAC
//
//  Created by Daniel Kuntz on 7/25/23.
//

import SwiftUI

enum AndiEmptyStateType: String {
    case shoes
    case fly
}

struct AndiEmptyState: View {
    var text: String
    var type: AndiEmptyStateType = .shoes

    var body: some View {
        VStack {
            Image("andi-\(type.rawValue)")
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding([.leading, .trailing], 50)
                .multilineTextAlignment(.center)
                .lineLimit(10)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

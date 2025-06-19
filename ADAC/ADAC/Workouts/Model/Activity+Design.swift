// Licensed under the Any Distance Source-Available License
//
//  Activity+Design.swift
//  ADAC
//
//  Created by Jarod Luebbert on 4/21/22.
//

import Foundation

extension Activity {
    
    var design: ActivityDesign {
        get {
            return ActivityDesignStore.shared.design(for: self)
        }
    }
    
}

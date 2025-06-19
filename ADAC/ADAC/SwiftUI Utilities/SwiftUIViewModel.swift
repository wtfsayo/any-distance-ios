// Licensed under the Any Distance Source-Available License
//
//  SwiftUIViewModel.swift
//  ADAC
//
//  Created by Daniel Kuntz on 1/3/22.
//

import UIKit

class SwiftUIViewModel<T: UIViewController>: NSObject, ObservableObject {
    weak var controller: T?

    init(controller: T) {
        self.controller = controller
    }
}

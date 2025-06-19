// Licensed under the Any Distance Source-Available License
//
//  NoActionsTextField.swift
//  ADAC
//
//  Created by Daniel Kuntz on 2/20/21.
//

import UIKit

final class NoActionsTextField: UITextField {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }
}

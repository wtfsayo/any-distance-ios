// Licensed under the Any Distance Source-Available License
//
//  DesignableView.swift
//  Beet
//
//  Created by Daniel Kuntz on 4/29/19.
//  Copyright © 2019 Coda Labs. All rights reserved.
//

import UIKit

class DesignableView: UIView {
    
    // MARK: - Outlets
    
    @IBOutlet var view: UIView!

    // MARK: - Setup
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadView()
    }
    
    final internal func loadView() {
        Bundle.main.loadNibNamed(String(describing: type(of: self)), owner: self, options: nil)
        self.view.frame = bounds
        self.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.backgroundColor = .clear
        addSubview(self.view)
        
        setup()
    }
    
    open func setup() {}
}

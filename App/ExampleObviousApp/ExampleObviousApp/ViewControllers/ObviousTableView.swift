//////////////////////////////////////////////////////////////////////////
// Copyright © 2019,
// 4iiii Innovations Inc.,
// Cochrane, Alberta, Canada.
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are not permitted without express written approval of
// 4iiii Innovations Inc.
///////////////////////////////////////////////////////////////////////

import UIKit

@IBDesignable class ObviousTableView: UITableView {
    
    @IBInspectable var outlineWidth: CGFloat = 0.0
    @IBInspectable var cornerRadius: CGFloat = 8.0
    @IBInspectable var outlineColor: UIColor? {
        didSet {
            self.setup()
        }
    }
    
    public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    private func setup() {
        self.layer.cornerRadius = cornerRadius
        self.layer.borderColor = outlineColor?.cgColor ?? UIColor(named: "PrimaryLight")!.cgColor
        self.layer.borderWidth = outlineWidth
        self.backgroundColor = UIColor(named: "PrimaryLight")!
        self.tableFooterView = UIView(frame: .zero)
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setup()
    }
}


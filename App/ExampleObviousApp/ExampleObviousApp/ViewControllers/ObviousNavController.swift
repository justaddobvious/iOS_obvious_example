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

class ObviousNavController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    public func setup() {
        self.navigationBar.tintColor = UIColor(named: "PrimaryLight")
        self.navigationBar.barTintColor = UIColor(named: "PrimaryDark")!
        self.navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor(named: "PrimaryLight")!,
        ]
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setup()
    }
    
}

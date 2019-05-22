//////////////////////////////////////////////////////////////////////////
// Copyright © 2019,
// 4iiii Innovations Inc.,
// Cochrane, Alberta, Canada.
// All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are not permitted without express written approval of
// 4iiii Innovations Inc.
///////////////////////////////////////////////////////////////////////

import Foundation

class StateManager {
    
    public static let shared: StateManager = StateManager()
    
    private init() {  }
    
    public var currentSerialNumber: String? = nil
    public var purchaseMade: Bool = false
}

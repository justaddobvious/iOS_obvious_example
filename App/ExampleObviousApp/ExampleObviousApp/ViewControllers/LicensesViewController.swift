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

public struct LicensesData {
    let titleText: String
    let url: URL
}

class LicensesViewController: UITableViewController {
    private var licenses: [LicensesData] = [
        LicensesData(titleText: "Font Awesome", url: URL(string: "https://raw.githubusercontent.com/FortAwesome/Font-Awesome/master/LICENSE.txt")!),
        LicensesData(titleText: "ObviousAPI", url: URL(string: "https://obvious.xyz/")!)
    ]
    
    private let licenseCellIdentifier: String = "licenseCell"
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return licenses.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: licenseCellIdentifier, for: indexPath)
        
        let license = licenses[indexPath.row]
        cell.textLabel?.text = license.titleText
        cell.textLabel?.textColor = UIColor(named: "PrimaryDark")!
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UIApplication.shared.open(licenses[indexPath.row].url, options: [:], completionHandler: nil)
    }
}

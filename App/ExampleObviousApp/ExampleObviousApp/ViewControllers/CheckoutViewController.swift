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
import ObviousAPI
import Stripe

class CheckoutViewController: UIViewController {
    
    @IBOutlet weak var checkoutTableView: UITableView!
    @IBOutlet weak var totalPriceLabel: UILabel!
    
    public var checkoutList: [CatalogItem] = []
    public var catalogInteractor: OcelotCatalogInteractor!
    public var totalPrice: String!
    public var cartId: Int!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        totalPriceLabel.text = totalPrice
        catalogInteractor.setCheckoutListener(self)
        checkoutTableView.dataSource = self
        checkoutTableView.delegate = self
    }
    
    @IBAction func confirmButtonPressed(_ sender: Any) {
        if let serial = StateManager.shared.currentSerialNumber {
            let cardParams = STPCardParams()
            cardParams.name = "Batman"
            cardParams.number = "4242424242424242"
            cardParams.expMonth = 4
            cardParams.expYear = 33
            cardParams.cvc = "242"
            
            STPAPIClient.shared().createToken(withCard: cardParams) { [unowned self] (token: STPToken?, error: Error?) in
                if error != nil {
                    let alert = UIAlertController(title: "Payment Failed", message: "Payment could not be processed.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                } else {
                    self.catalogInteractor.checkoutPay(cartId: self.cartId, tokenId: token!.tokenId, serialNumber: serial, productIdentifier: OCELOTPRODUCTIDENTIFIER.EXAMPLE_MANUFACTURER_PRODUCT_ID)
                }
            }
            
            
        } else {
            let alert = UIAlertController(title: "Serial Number Not Found", message: "Please connect to an Obvious device first.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension CheckoutViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return checkoutList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "checkoutCell", for: indexPath)
        
        let item = checkoutList[indexPath.row]
        cell.textLabel?.text = item.name
        return cell
    }
}

extension CheckoutViewController: OcelotCatalogCheckoutResultListener {
    func onCheckoutCartSuccess(_ totalPrice: Int, _ cartId: Int) {
        // Handle checkout cart success event here
    }
    
    func onCheckoutCartFail(_ error: String?) {
        // Handle checkout cart failure event here
    }
    
    func onCheckoutPaySuccess() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "Payment Success", message: "Payment successfully processed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: { action in
                StateManager.shared.purchaseMade = true
                self?.navigationController?.popToRootViewController(animated: true)
                self?.tabBarController?.selectedIndex = 0
            }))
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    func onCheckoutPayFail(_ error: String?) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(title: "Payment Failed", message: "Payment could not be processed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
            self?.present(alert, animated: true, completion: nil)
        }
    }
}

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

class CheckoutViewController: UIViewController {
    
    @IBOutlet weak var checkoutTableView: UITableView!
    @IBOutlet weak var totalPriceLabel: UILabel!
    
    public var checkoutList: [CatalogItem] = []
    public var catalogInteractor: OcelotCatalogInteractor!
    private var paymentClient: OcelotPaymentClient?
    private lazy var paymentFailedAlert: UIAlertController = UIAlertController(title: "Payment Failed", message: "Payment could not be processed.", preferredStyle: .alert)
    public var totalPrice: String!
    public var cartId: Int!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        paymentFailedAlert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
        totalPriceLabel.text = totalPrice
        catalogInteractor.setCheckoutListener(self)
        paymentClient = OcelotPaymentClient.getDemoPaymentClient(obviousClient: catalogInteractor, listener: self)
        checkoutTableView.dataSource = self
        checkoutTableView.delegate = self
    }
    
    @IBAction func confirmButtonPressed(_ sender: Any) {
        if let serial = StateManager.shared.currentSerialNumber {
            
        paymentClient?.startPaymentProcessing(cardNumber: "4242424242424242",
                                              cardExpMonth: 4,
                                              cardExpYear: 33,
                                              cardCVC: "242",
                                              cartId: cartId,
                                              serialNumber: serial,
                                              productId: OCELOTPRODUCTIDENTIFIER.EXAMPLE_MANUFACTURER_PRODUCT_ID)
            
            
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
    func onCheckoutPayActionRequired(_ paymentSecret: String) {
        paymentClient?.authenticatePayment(viewController: self, cartId: cartId, paymentSecret: paymentSecret, isPresentingApplePay: false)
    }
    
    func onCheckoutCartSuccess(_ totalPrice: Int, _ cartId: Int) {
        // MARK: Handle checkout cart success event here
    }
    
    func onCheckoutCartFail(_ error: String?) {
        // MARK: Handle checkout cart failure event here
        DispatchQueue.main.async { [weak self] in
            if let alert = self?.paymentFailedAlert {
                self?.present(alert, animated: true, completion: nil)
            }
        }
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
        // MARK: Handle checkout pay failure event here.
        DispatchQueue.main.async { [weak self] in
            if let alert = self?.paymentFailedAlert {
                self?.present(alert, animated: true, completion: nil)
            }
        }
    }
}

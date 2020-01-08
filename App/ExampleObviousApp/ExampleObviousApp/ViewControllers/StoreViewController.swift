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

class StoreViewController: ObviousViewController {

    @IBOutlet weak var storeTableView: UITableView!
    
    private let catalogInteractor: OcelotCatalogInteractor = OcelotCatalogInteractor.getDemoCatalogInteractor()
    private let storeCellIdentifier: String = "storeCell"
    private var catalogList: [CatalogItem] = []
    private var selectedCatalogList: [CatalogItem] = []
    private var indexArray: [IndexPath] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        catalogInteractor.setAPIKey(OCELOTPRODUCTIDENTIFIER.EXAMPLE_API_KEY)
        catalogInteractor.setCatalogListListener(self)
        storeTableView.dataSource = self
        storeTableView.delegate = self
        catalogInteractor.getDefaultCatalog()   
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        catalogInteractor.setCheckoutListener(self)
    }
    
    @IBAction func checkoutButtonPressed(_ sender: Any) {
        if selectedCatalogList.count == 0 {
            let alert = UIAlertController(title: "No Items Selected", message: "Please select an item first.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        if let serial = StateManager.shared.currentSerialNumber {
            catalogInteractor.checkoutCart(checkout: selectedCatalogList, serialNumber: serial, productIdentifier: OCELOTPRODUCTIDENTIFIER.EXAMPLE_MANUFACTURER_PRODUCT_ID)
        } else {
            let alert = UIAlertController(title: "Serial Number Not Found", message: "Please connect to an Obvious device first.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
}

extension StoreViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return catalogList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: storeCellIdentifier, for: indexPath)
        
        let catalogItem = catalogList[indexPath.row]
        cell.textLabel?.text = catalogItem.name
        cell.detailTextLabel?.text = "$" + catalogItem.itemprice
        cell.imageView?.download(from: catalogItem.imageurl) {
            cell.setNeedsLayout()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedCatalogList.append(catalogList[indexPath.row])
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        selectedCatalogList.removeAll(where: { item in item.id == catalogList[indexPath.row].id})
    }
}

extension StoreViewController: OcelotCatalogListResultListener {
    func onCatalogListSuccess(_ catalogList: [CatalogItem]) {
        DispatchQueue.main.async { [weak self] in
            print("\(catalogList)")
            self?.catalogList = catalogList
            self?.storeTableView.reloadData()
        }
    }
    
    func onCatalogListRequestFail(_ error: String?) {
        // MARK: Handle catalog list request fail event here.
    }
}

extension StoreViewController: OcelotCatalogCheckoutResultListener {
    func onCheckoutPayActionRequired(_ paymentSecret: String) {
        // MARK: If a checkout payment event requires further authentication, handle the payment secret from this
        // callback.
    }
    
    func onCheckoutCartSuccess(_ totalPrice: Int, _ cartId: Int) {
        DispatchQueue.main.async { [weak self] in
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let newVC = storyboard.instantiateViewController(withIdentifier: "CheckoutViewController") as! CheckoutViewController
            newVC.checkoutList = self?.selectedCatalogList ?? []
            newVC.catalogInteractor = self?.catalogInteractor
            newVC.totalPrice = "$" + String(Float(totalPrice) / 100)
            newVC.cartId = cartId
            self?.navigationController?.pushViewController(newVC, animated: true)
        }
    }
    
    func onCheckoutCartFail(_ error: String?) {
        // MARK: Handle checkout cart failure event here.
    }
    
    func onCheckoutPaySuccess() {
        // MARK: Handle checkout pay success event here.
    }
    
    func onCheckoutPayFail(_ error: String?) {
        // MARK: Handle checkout pay failure event here.
    }
}

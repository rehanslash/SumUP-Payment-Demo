//
//  ViewController.swift
//  sumUp
//
//  Created by HigherVisibility on 28/08/2018.
//  Copyright © 2018 ahmedHigherVisibility. All rights reserved.
//

import UIKit
import SumUpSDK


class ViewController: UIViewController {

    //MARK: OutletS
    
    @IBOutlet weak var logoutBtn_outlet: UIButton!
    @IBOutlet weak var loginBtn_outlet: UIButton!
    
    @IBOutlet weak var textFieldTotal: UITextField!
    
    @IBOutlet weak var textFieldTitle: UITextField!
    
    @IBOutlet weak var label: UILabel!
    
    
    //MARK:View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.textFieldTotal.delegate = self
        self.textFieldTitle.delegate = self
        
        self.textFieldTotal.layer.borderColor = UIColor.black.cgColor
        self.textFieldTotal.layer.borderWidth = 2
        
        self.textFieldTitle.layer.borderColor = UIColor.black.cgColor
        self.textFieldTitle.layer.borderWidth = 2
        
    }

    
    
    override func viewWillAppear(_ animated: Bool) {
        self.updateButtonStates()
    }
    
     //MARK:Button Action
    
    @IBAction func preferenceBtn_action(_ sender: Any) {
        
      self.presentCheckoutPreferences()
        
    }
    
    
    @IBAction func chargeBtn_action(_ sender: Any) {
        
        self.requestCheckout()
        
    }
    
    
    @IBAction func loginBtn_action(_ sender: Any) {
        
        self.presentLogin()
        
    }
    
    
    @IBAction func signOutBtn_action(_ sender: Any) {
        
        
         self.requestLogout()
        
    }
    
    private func presentLogin() {
        // present login UI and wait for completion block to update button states
        SumUpSDK.presentLogin(from: self, animated: true) { [weak self] (success: Bool, error: Error?) in
            print("Did present login with success: \(success). Error: \(String(describing: error))")
            
            guard error == nil else {
                // errors are handled within the SDK, there should be no need
                // for your app to display any error message
                return
            }
            
           // self?.updateCurrency()
            self?.updateButtonStates()
        }
    }
    
    fileprivate func showResult(string: String) {
        label?.text = string
        // fade in label
        UIView.animateKeyframes(withDuration: 3, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
            let relativeDuration = TimeInterval(0.15)
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: relativeDuration) {
                self.label?.alpha = 1.0
            }
            UIView.addKeyframe(withRelativeStartTime: 1.0 - relativeDuration, relativeDuration: relativeDuration) {
               self.label?.alpha = 0.0
            }
        }, completion: nil)
    }
    
    
    private func presentCheckoutPreferences() {
        SumUpSDK.presentCheckoutPreferences(from: self, animated: true) { [weak self] (success: Bool, presentationError: Error?) in
            print("Did present checkout preferences with success: \(success). Error: \(String(describing: presentationError))")
            
            guard let safeError = presentationError as NSError? else {
                // no error, nothing else to do
                return
            }
            
            print("error presenting checkout preferences: \(safeError)")
            
            let errorMessage: String
            switch (safeError.domain, safeError.code) {
            case (SumUpSDKErrorDomain, SumUpSDKError.accountNotLoggedIn.rawValue):
                errorMessage = "not logged in"
                
            case (SumUpSDKErrorDomain, SumUpSDKError.checkoutInProgress.rawValue):
                errorMessage = "checkout is in progress"
                
            default:
                errorMessage = "general error"
            }
            
            self?.showResult(string: errorMessage)
        }
    }
    
    fileprivate func requestLogout() {
        
        SumUpSDK.logout { [weak self] (success: Bool, error: Error?) in
            print("Did log out with success: \(success). Error: \(String(describing: error))")
            self?.updateButtonStates()
            
        }
    }
    
    fileprivate func requestCheckout() {
        
        // ensure that we have a valid merchant
        guard let merchantCurrencyCode = SumUpSDK.currentMerchant?.currencyCode else {
            showResult(string: "not logged in")
            return
        }
        
        guard let totalText = textFieldTotal?.text else {
            return
        }
        
        // create an NSDecimalNumber from the totalText
        // please be aware to not use NSDecimalNumber initializers inherited from NSNumber
        let total = NSDecimalNumber(string: totalText)
        guard total != NSDecimalNumber.zero else {
            return
        }
        
        // setup payment request
        let request = CheckoutRequest(total: total,
                                      title: textFieldTitle?.text,
                                      currencyCode: merchantCurrencyCode,
                                      paymentOptions: [.cardReader, .mobilePayment])
        
//        // add tip if selected
//        if let selectedTip = segmentedControlTipping?.selectedSegmentIndex,
//            selectedTip > 0,
//            tipAmounts.indices ~= selectedTip {
//            let tipAmount = tipAmounts[selectedTip]
//            request.tipAmount = tipAmount
//        }
//
//        // set screenOptions to skip if switch is set to on
//        if let skip = switchSkipReceiptScreen?.isOn, skip {
//            request.skipScreenOptions = .success
//        }
        
        // the foreignTransactionID is an **optional** parameter and can be used
        // to retrieve a transaction from SumUp's API. See -[SMPCheckoutRequest foreignTransactionID]
        request.foreignTransactionID = "your-unique-identifier-\(ProcessInfo.processInfo.globallyUniqueString)"
        
        SumUpSDK.checkout(with: request, from: self) { [weak self] (result: CheckoutResult?, error: Error?) in
            if let safeError = error as NSError? {
                print("error during checkout: \(safeError)")
                
                if (safeError.domain == SumUpSDKErrorDomain) && (safeError.code == SumUpSDKError.accountNotLoggedIn.rawValue) {
                    self?.showResult(string: "not logged in")
                } else {
                    self?.showResult(string: "general error")
                }
                
                return
            }
            
            guard let safeResult = result else {
                print("no error and no result should not happen")
                return
            }
            
            print("result_transaction==\(String(describing: safeResult.transactionCode))")
            
            if safeResult.success {
                print("success")
                var message = "Thank you - \(String(describing: safeResult.transactionCode))"
                
                if let info = safeResult.additionalInfo,
                    let tipAmount = info["tip_amount"] as? Double, tipAmount > 0,
                    let currencyCode = info["currency"] as? String {
                    message = message.appending("\ntip: \(tipAmount) \(currencyCode)")
                }
                
                self?.showResult(string: message)
            } else {
                print("cancelled: no error, no success")
                self?.showResult(string: "No charge (cancelled)")
            }
        }
        
        // after the checkout is initiated we expect a checkout to be in progress
        if !SumUpSDK.checkoutInProgress {
            // something went wrong: checkout was not started
            showResult(string: "failed to start checkout")
        }
    }

}

extension ViewController {
    
    fileprivate func updateButtonStates() {
        
        let isLoggedIn = SumUpSDK.isLoggedIn
      
        self.loginBtn_outlet.isEnabled = !isLoggedIn
        self.logoutBtn_outlet.isEnabled = isLoggedIn
    }
    
}


extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == textFieldTotal {
            // we assume a checkout is imminent
            // let the SDK know to e.g. wake a connected terminal
            SumUpSDK.prepareForCheckout()
            
            textFieldTitle?.becomeFirstResponder()
        } else if SumUpSDK.isLoggedIn {
            requestCheckout()
        } else {
            textField.resignFirstResponder()
        }
        
        return true
    }
}

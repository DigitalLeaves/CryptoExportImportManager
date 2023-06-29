//
//  ImportViewController.swift
//  CryptoLoadExternalCertificate
//
//  Created by Ignacio Nieto Carvajal on 11/10/15.
//  Copyright © 2015 Ignacio Nieto Carvajal. All rights reserved.
//

import UIKit

class ImportViewController: UIViewController {
    // outlets && buttons
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    @IBAction func importKey(_ sender: AnyObject) {
        // first try to get the path for certificate.der
        guard let certPath = Bundle.main.path(forResource: "certificate", ofType: "der") else {
            textView.text = "An error happened while reading the certificate file. Unable to get path for certificate.der"
            return
        }
        
        // now get the data from the certificate file
        guard let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)) else {
            textView.text = "An error happened while reading the certificate file. Unable to read certificate.der"
            return
        }
        
        // if we got the certificate data, let's extract the public key reference.
        if let publicKeyRef = CryptoExportImportManager.importPublicKeyReferenceFromDERCertificate(certData) {
            textView.text = "Successfully extracted public key from certificate:\n\(publicKeyRef)\n"
        } else {
            textView.text = "Oups! I was unable to retrieve a public key from the certificate."
        }
    }

}

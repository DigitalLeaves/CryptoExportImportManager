//
//  ExportViewController.swift
//  CryptoLoadExternalCertificate
//
//  Created by Ignacio Nieto Carvajal on 11/10/15.
//  Copyright © 2015 Ignacio Nieto Carvajal. All rights reserved.
//

import UIKit

private let kExportKeyTag = "com.CryptoLoadExternalCertificate.exampleKey"

class ExportViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var keyTypeSegment: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getKeyTypeFromSegmentedControl() -> String {
        if self.keyTypeSegment.selectedSegmentIndex == 0 {
            return kSecAttrKeyTypeEC as String
        } else {
            return kSecAttrKeyTypeRSA as String
        }
    }
    
    func getKeyLengthFromSegmentedControl() -> Int {
        if self.keyTypeSegment.selectedSegmentIndex == 0 {
            return 256 // EC key length
        } else {
            return 2048 // RSA 2048
        }
    }

    @IBAction func generateAndExportPublicKey(_ sender: AnyObject) {
        self.view.isUserInteractionEnabled = false
        self.textView.text = "Trying to get public key data from Keychain first..."
        let keyType = getKeyTypeFromSegmentedControl()
        if let publicKeyData = getPublicKeyData(kExportKeyTag + keyType) {
            self.textView.text = self.textView.text + "Success!\nPublic key raw bytes: \(publicKeyData.hexDescription)\n\n"
            self.exportKeyFromRawBytesAndShowInTextView(publicKeyData)
            self.view.isUserInteractionEnabled = true
        } else {
            self.textView.text = self.textView.text + "Failed! Will try to generate keypair...\n"
            createSecureKeyPair(kExportKeyTag + keyType) { (success, pubKeyData) -> Void in
                if success && pubKeyData != nil {
                    self.textView.text = self.textView.text + "Success!\nPublic key raw bytes:\(pubKeyData!)\n"
                    self.exportKeyFromRawBytesAndShowInTextView(pubKeyData!)
                } else {
                    self.textView.text = self.textView.text + "Oups! I was unable to generate the keypair to test the export functionality."
                }
                self.view.isUserInteractionEnabled = true
            }
        }
    }
    
    func exportKeyFromRawBytesAndShowInTextView(_ rawBytes: Data) {
        let keyType = getKeyTypeFromSegmentedControl()
        let keySize = getKeyLengthFromSegmentedControl()
        let exportImportManager = CryptoExportImportManager()
        if let exportableDERKey = exportImportManager.exportPublicKeyToDER(rawBytes, keyType: keyType, keySize: keySize) {
            self.textView.text = self.textView.text + "Exportable key in DER format:\n\(exportableDERKey.hexDescription)\n\n"
            print("Exportable key in DER format:\n\(exportableDERKey.hexDescription)\n")
            let exportablePEMKey = exportImportManager.PEMKeyFromDERKey(exportableDERKey)
            self.textView.text = self.textView.text + "Exportable key in PEM format:\n\(exportablePEMKey)\n\n"
            print("Exportable key in PEM format:\n\(exportablePEMKey)\n")
        } else {
            self.textView.text = self.textView.text + "Unable to generate DER key from raw bytes."
        }
    }
    
    @IBAction func deleteGeneratedKey(_ sender: AnyObject) {
        self.deleteSecureKeyPair(kExportKeyTag + getKeyTypeFromSegmentedControl()) { (success) -> Void in
            self.textView.text = success ? "Successfully deleted keypair" : "Error deleting keypair. Maybe the key didn't exist?"
        }
    }
    
    
    // MARK: - Auxiliary key generation and management methods
    
    func createSecureKeyPair(_ keyTag: String, completion: ((_ success: Bool, _ pubKeyData: Data?) -> Void)? = nil) {
        // private key parameters
        let privateKeyParams: [String: AnyObject] = [
            kSecAttrIsPermanent as String: true as AnyObject,
            kSecAttrApplicationTag as String: keyTag as AnyObject,
        ]
        
        // private key parameters
        let publicKeyParams: [String: AnyObject] = [
            kSecAttrApplicationTag as String: keyTag as AnyObject,
            kSecAttrIsPermanent as String: true as AnyObject
        ]
        
        // global parameters for our key generation
        let parameters: [String: AnyObject] = [
            kSecAttrKeyType as String:          getKeyTypeFromSegmentedControl() as AnyObject,
            kSecAttrKeySizeInBits as String:    getKeyLengthFromSegmentedControl() as AnyObject,
            kSecPublicKeyAttrs as String:       publicKeyParams as AnyObject,
            kSecPrivateKeyAttrs as String:      privateKeyParams as AnyObject,
        ]
        
        // asynchronously generate the key pair and call the completion block
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { () -> Void in
            var pubKey, privKey: SecKey?
            let status = SecKeyGeneratePair(parameters as CFDictionary, &pubKey, &privKey)
            if status == errSecSuccess {
                DispatchQueue.main.async(execute: {
                    print("Successfully generated keypair!\nPrivate key: \(privKey)\nPublic key: \(pubKey)")
                    let publicKeyData = self.getPublicKeyData(kExportKeyTag + self.getKeyTypeFromSegmentedControl())
                    completion?(true, publicKeyData)
                })
            } else {
                DispatchQueue.main.async(execute: {
                    print("Error generating keypair: \(status)")
                    completion?(false, nil)
                })
            }
        }
    }
    
    func getPublicKeyData(_ keyTag: String) -> Data? {
        let parameters = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: getKeyTypeFromSegmentedControl(),
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrApplicationTag as String: keyTag,
            kSecReturnData as String: true
        ] as [String : Any]
        var data: AnyObject?
        let status = SecItemCopyMatching(parameters as CFDictionary, &data)
        if status == errSecSuccess {
            return data as? Data
        } else { print("Error getting public key data: \(status)"); return nil }
    }
    
    func deleteSecureKeyPair(_ keyTag: String, completion: ((_ success: Bool) -> Void)?) {
        // private query dictionary
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: getKeyTypeFromSegmentedControl(),
            kSecAttrApplicationTag as String: keyTag,
        ] as [String : Any]
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { () -> Void in
            let status = SecItemDelete(query as CFDictionary) // delete key
            DispatchQueue.main.async(execute: { completion?(status == errSecSuccess) })
        }
    }
}

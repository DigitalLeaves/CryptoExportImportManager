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

    @IBAction func generateAndExportPublicKey(sender: AnyObject) {
        self.view.userInteractionEnabled = false
        self.textView.text = "Trying to get public key data from Keychain first..."
        let keyType = getKeyTypeFromSegmentedControl()
        if let publicKeyData = getPublicKeyData(kExportKeyTag + keyType) {
            self.textView.text = self.textView.text.stringByAppendingString("Success!\nPublic key raw bytes: \(publicKeyData)\n")
            self.exportKeyFromRawBytesAndShowInTextView(publicKeyData)
            self.view.userInteractionEnabled = true
        } else {
            self.textView.text = self.textView.text.stringByAppendingString("Failed! Will try to generate keypair...\n")
            createSecureKeyPair(kExportKeyTag + keyType) { (success, pubKeyData) -> Void in
                if success && pubKeyData != nil {
                    self.textView.text = self.textView.text.stringByAppendingString("Success!\nPublic key raw bytes:\(pubKeyData!)\n")
                    self.exportKeyFromRawBytesAndShowInTextView(pubKeyData!)
                } else {
                    self.textView.text = self.textView.text.stringByAppendingString("Oups! I was unable to generate the keypair to test the export functionality.")
                }
                self.view.userInteractionEnabled = true
            }
        }
    }
    
    func exportKeyFromRawBytesAndShowInTextView(rawBytes: NSData) {
        let keyType = getKeyTypeFromSegmentedControl()
        let keySize = getKeyLengthFromSegmentedControl()
        let exportImportManager = CryptoExportImportManager()
        if let exportableDERKey = exportImportManager.exportPublicKeyToDER(rawBytes, keyType: keyType, keySize: keySize) {
            self.textView.text = self.textView.text.stringByAppendingString("Exportable key in DER format:\n\(exportableDERKey)")
            print("Exportable key in DER format:\n\(exportableDERKey)")
            let exportablePEMKey = exportImportManager.PEMKeyFromDERKey(exportableDERKey)
            self.textView.text = self.textView.text.stringByAppendingString("Exportable key in PEM format:\n\(exportablePEMKey)")
            print("Exportable key in PEM format:\n\(exportablePEMKey)")
        } else {
            self.textView.text = self.textView.text.stringByAppendingString("Unable to generate DER key from raw bytes.")
        }
    }
    
    @IBAction func deleteGeneratedKey(sender: AnyObject) {
        self.deleteSecureKeyPair(kExportKeyTag + getKeyTypeFromSegmentedControl()) { (success) -> Void in
            self.textView.text = success ? "Successfully deleted keypair" : "Error deleting keypair. Maybe the key didn't exist?"
        }
    }
    
    
    // MARK: - Auxiliary key generation and management methods
    
    func createSecureKeyPair(keyTag: String, completion: ((success: Bool, pubKeyData: NSData?) -> Void)? = nil) {
        // private key parameters
        let privateKeyParams: [String: AnyObject] = [
            kSecAttrIsPermanent as String: true,
            kSecAttrApplicationTag as String: keyTag,
        ]
        
        // private key parameters
        let publicKeyParams: [String: AnyObject] = [
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrIsPermanent as String: true
        ]
        
        // global parameters for our key generation
        let parameters: [String: AnyObject] = [
            kSecAttrKeyType as String:          getKeyTypeFromSegmentedControl(),
            kSecAttrKeySizeInBits as String:    getKeyLengthFromSegmentedControl(),
            kSecPublicKeyAttrs as String:       publicKeyParams,
            kSecPrivateKeyAttrs as String:      privateKeyParams,
        ]
        
        // asynchronously generate the key pair and call the completion block
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            var pubKey, privKey: SecKeyRef?
            let status = SecKeyGeneratePair(parameters, &pubKey, &privKey)
            if status == errSecSuccess {
                dispatch_async(dispatch_get_main_queue(), {
                    print("Successfully generated keypair!\nPrivate key: \(privKey)\nPublic key: \(pubKey)")
                    let publicKeyData = self.getPublicKeyData(kExportKeyTag + self.getKeyTypeFromSegmentedControl())
                    completion?(success: true, pubKeyData: publicKeyData)
                })
            } else {
                dispatch_async(dispatch_get_main_queue(), {
                    print("Error generating keypair: \(status)")
                    completion?(success: false, pubKeyData: nil)
                })
            }
        }
    }
    
    private func getPublicKeyData(keyTag: String) -> NSData? {
        let parameters = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: getKeyTypeFromSegmentedControl(),
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrApplicationTag as String: keyTag,
            kSecReturnData as String: true
        ]
        var data: AnyObject?
        let status = SecItemCopyMatching(parameters, &data)
        if status == errSecSuccess {
            return data as? NSData
        } else { print("Error getting public key data: \(status)"); return nil }
    }
    
    func deleteSecureKeyPair(keyTag: String, completion: ((success: Bool) -> Void)?) {
        // private query dictionary
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: getKeyTypeFromSegmentedControl(),
            kSecAttrApplicationTag as String: keyTag,
        ]
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) { () -> Void in
            let status = SecItemDelete(query) // delete key
            dispatch_async(dispatch_get_main_queue(), { completion?(success: status == errSecSuccess) })
        }
    }
}

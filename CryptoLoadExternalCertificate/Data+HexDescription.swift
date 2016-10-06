//
//  Data+HexDescription.swift
//  CryptoLoadExternalCertificate
//
//  Created by Ignacio Nieto Carvajal on 6/10/16.
//  Copyright © 2016 Ignacio Nieto Carvajal. All rights reserved.
//

import Foundation

extension Data {
    var hexDescription: String {
        return self.map { String(format: "%02hhx", $0) }.joined()
    }
}

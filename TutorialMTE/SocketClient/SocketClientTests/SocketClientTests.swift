//
// ******************************************************
// SocketClient Project
// SocketClientTests.swift created on 9/28/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ******************************************************


import XCTest
@testable import SocketClient

class SocketClientTests: XCTestCase {

    func testMTE() throws {
        
        print(MteBase.getVersion())
        
        let plaintext = "This is a secret!"
        
        // Status
        var status: mte_status!

        var encoder: MteEnc!
        var decoder: MteDec!

        let nonce: UInt64 = 0

        // Check mte license
        XCTAssertNotNil(MteBase.initLicense("LicenseCompanyName", "LicenseKey"))

        let personalizationString: String = "demo"

        // MARK: MTE Setup

        // Initialize Encoder
        encoder = try MteEnc()
        
        // IMPORTANT! ** This is an entirely insecure way of setting Entropy and MUST NOT be used in a "real"
        // application. PLease see MTE Developer's Guide for more information.
        // Create all-zero entropy for this lab.
        let entropyBytes = MteBase.getDrbgsEntropyMinBytes(encoder.getDrbg())
        var entropy = [UInt8](repeating: 0, count: entropyBytes)

        encoder.setEntropy(&entropy)
        encoder.setNonce(nonce)
        status = encoder.instantiate([UInt8](personalizationString.utf8))
        XCTAssertEqual(status, mte_status_success)
        XCTAssertNoThrow(encoder)
    
        // Initialize Decoder
        decoder = try MteDec()
        decoder.setEntropy(&entropy)
        decoder.setNonce(nonce)
        status = decoder.instantiate([UInt8](personalizationString.utf8))
        XCTAssertEqual(status, mte_status_success)
        XCTAssertNoThrow(encoder)
        
        // Encode the plaintext with MTE
        let encodeResult = encoder.encode([UInt8](plaintext.utf8))
        XCTAssertEqual(encodeResult.status, mte_status_success)
        print("Encoded response data (as Ascii Hex only for display here): \n\t\([UInt8](encodeResult.encoded).bytesToHex())")
        
        // decode the encoded plaintext
        let decodeResult = decoder.decode([UInt8](encodeResult.encoded))
        XCTAssertEqual(decodeResult.status, mte_status_success)
        let message = String(bytes: decodeResult.decoded, encoding: .utf8)
        XCTAssertNotNil(message)
        print("Decoded Message: \n\t\(message!)")
        
        XCTAssertEqual(message, plaintext)
    }

}

extension Array where Element == UInt8 {
    var data : Data {
        return Data(self)
    }
    
    func bytesToHex(spacing: String = "") -> String {
        var hexString: String = ""
        var count = self.count
        for byte in self
        {
            hexString.append(String(format:"%02X", byte))
            count = count - 1
            if count > 0
            {
                hexString.append(spacing)
            }
        }
        return hexString
    }
}

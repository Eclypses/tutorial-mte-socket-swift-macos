//
// ******************************************************
// SocketServer Project
// SocketServerTests.swift created on 9/16/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ******************************************************


import XCTest
import SocketServer

class SocketServerTests: XCTestCase {

    func testMTE() throws {
        
        print(MteBase.getVersion())
        
        let plaintext = "This is a secret!"
        
        // Status
        var status: mte_status!

        var encoder: MteEnc!
        var decoder: MteDec!

        let nonce: UInt64 = 0

        // Options
        var drbg: mte_drbgs = mte_drbgs_ctr_aes256_df
        var tokenBytes: Int = 8 // Number of payload bytes each packet byte is expanded to.
        var byteValMin: Int = 0
        var byteValCount: Int = 256
        var verifier: mte_verifiers = mte_verifiers_none
        let timeStampWindow: UInt64 = 1 // number of seconds in-transit permitted if timestamp verification is turned on.
        let sequenceWindow: Int = 0 // number of dropped packets permitted if sequencing verification is turned on.

        // Check mte license
        XCTAssertNotNil(MteBase.initLicense("LicenseCompanyName", "LicenseKey"))

        // Set Options to the buildtime Options if they exist
        if MteBase.hasBuildtimeOpts() {
            
            // Set our Options varibles
            print("This MTE library has BuildTime Options so we will load them")
            drbg = MteBase.getBuildtimeDrbg()
            tokenBytes = MteBase.getBuildtimeTokBytes()
            byteValMin = MteBase.getBuildtimeByteValMin()
            byteValCount = MteBase.getBuildtimeByteValCount()
            verifier = MteBase.getBuildtimeVerifiers()
            print("BuildTime Options set")
        }

        // Self-test the drbg and check the status
        XCTAssertEqual(MteBase.drbgsSelfTest(drbg), mte_status_success)

        // IMPORTANT! ** This is an entirely insecure way of setting Entropy and MUST NOT be used in a "real"
        // application. PLease see MTE Developer's Guide for more information.
        // Create all-zero entropy for this lab.
        let entropyBytes = MteBase.getDrbgsEntropyMinBytes(drbg)
        let entropy = [UInt8](repeating: 0, count: entropyBytes)

        let personalizationString: String = "demo"

        // MARK: MTE Setup

        // Initialize Encoder
        encoder = try MteEnc(drbg, tokenBytes, byteValMin, byteValCount, verifier)
        encoder.setEntropy(entropy)
        encoder.setNonce(nonce)
        status = encoder.instantiate([UInt8](personalizationString.utf8))
        XCTAssertEqual(status, mte_status_success)
        XCTAssertNoThrow(encoder)
    
        // Initialize Decoder
        decoder = try MteDec(drbg, tokenBytes, byteValMin, byteValCount, verifier, timeStampWindow, sequenceWindow)
        decoder.setEntropy(entropy)
        decoder.setNonce(nonce)
        status = decoder.instantiate([UInt8](personalizationString.utf8))
        XCTAssertEqual(status, mte_status_success)
        XCTAssertNoThrow(encoder)
        
        // Encode the plaintext with MTE
        let encodeResult = encoder.encode([UInt8](plaintext.utf8))
        XCTAssertEqual(encodeResult.status, mte_status_success)
        print("Encoded response data (as Ascii Hex only for display here): \n\t\(encodeResult.encoded.bytesToHex())")
        
        // decode the encoded plaintext
        let decodeResult = decoder.decode(encodeResult.encoded)
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

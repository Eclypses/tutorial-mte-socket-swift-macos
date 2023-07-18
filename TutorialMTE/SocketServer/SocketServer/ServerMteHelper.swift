/*
 THIS SOFTWARE MAY NOT BE USED FOR PRODUCTION. Otherwise,
 The MIT License (MIT)
 
 Copyright (c) Eclypses, Inc.
 
 All rights reserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import Foundation

public class ServerMteHelper {
    
    // =====================================
    // Step 1 - Encoder and Decoder Creation
    // =====================================
    //---------------------------------------------------
    // MKE and Fixed length add-ons are NOT in all SDK
    // MTE versions. If the name of the SDK includes
    // "-MKE" then it will contain the MKE add-on. If the
    // name of the SDK includes "-FLEN" then it contains
    // the Fixed length add-on.
    //--------------------------------------------------
    
#if USE_MTE_CORE
    private var encoder: MteEnc!
    private var decoder: MteDec!
#endif
#if USE_MKE_ADDON
    private var encoder: MteMkeEnc!
    private var decoder: MteMkeDec!
#endif
#if USE_FLEN_ADDON
    private var encoder: MteFlenEnc!
    private var decoder: MteDec!
#endif
    
    private var serverEncoderInfo: MteSetupInfo!
    private var serverDecoderInfo: MteSetupInfo!
    
    // Bools to check if all 4 parts have been received from the client.
    private var recvEncPeer = false
    private var recvDecPeer = false
    private var recvEncPersonal = false
    private var recvDecPersonal = false
    
    public init() throws {
        // ==================
        // Step 2 - Licensing
        // ==================
        // Initialize MTE license. If a license code is not required (e.g., trial
        // mode), this can be skipped.
        if !MteBase.initLicense(Settings.licenseCompanyName, Settings.licenseKey) {
            print("There was an error attempting to initialize the MTE license.")
            exit(EXIT_FAILURE)
        }
        
#if USE_MTE_CORE
        encoder = try MteEnc()
        decoder = try MteDec()
#endif
#if USE_MKE_ADDON
        encoder = try MteMkeEnc()
        decoder = try MteMkeDec()
#endif
#if USE_FLEN_ADDON
        encoder = try MteFlenEnc(Int(Settings.maxInputBytes))
        decoder = try MteDec()
#endif
        serverEncoderInfo = try MteSetupInfo()
        serverDecoderInfo = try MteSetupInfo()
        
        // =====================================
        // Step 3 - Information Exchange
        // Review main.swift for implementation.
        // =====================================        
    }
    
    
    public func setEncoderPeerKey(data:[uint8]) {
        recvEncPeer = true
        serverEncoderInfo.setPeerPublicKey(data: data)
    }
    
    public func setDecoderPeerKey(data:[uint8]) {
        recvDecPeer = true
        serverDecoderInfo.setPeerPublicKey(data: data)
    }
    
    public func setEncoderPersonal(data:[uint8]) {
        recvEncPersonal = true
        serverEncoderInfo.setPersonalization(data: data)
    }
    
    public func setDecoderPersonal(data:[uint8]) {
        recvDecPersonal = true
        serverDecoderInfo.setPersonalization(data: data)
    }
    
    public func setEncoderNonce(data:[uint8]) {
        serverEncoderInfo.setNonce(data: data)
    }
    
    public func setDecoderNonce(data:[uint8]) {
        serverDecoderInfo.setNonce(data: data)
    }
    
    public func getEncoderPublicKey() -> [uint8] {
        return serverEncoderInfo.getPublicKey()
    }
    
    public func getDecoderPublicKey() -> [uint8] {
        return serverDecoderInfo.getPublicKey()
    }
    
    public func getEncoderPeerKey() -> [uint8] {
        return serverEncoderInfo.getPeerPublicKey()
    }
    
    public func getDecoderPeerKey() -> [uint8] {
        return serverDecoderInfo.getPeerPublicKey()
    }
    
    public func getEncoderNonce() -> [uint8] {
        return serverEncoderInfo.getNonce()
    }
    
    public func getDecoderNonce() -> [uint8] {
        return serverDecoderInfo.getNonce()
    }
    
    public func getEncoderPersonal() -> [uint8] {
        return serverEncoderInfo.getPersonalization()
    }
    
    public func getDecoderPersonal() -> [uint8] {
        return serverDecoderInfo.getPersonalization()
    }
    
    public func hasReceivedAllMteInfo() -> Bool {
        return recvEncPeer && recvDecPeer && recvEncPersonal && recvDecPersonal
    }
    
    public static func getTimestamp() -> uint64 {
        return Date().toMilliseconds()
    }
    
    // ======================
    // Step 4 - Instantiation
    // ======================
    public func createEncoder() -> Bool {
        let publicKey = serverEncoderInfo.getPublicKey()
        let peerKey = serverEncoderInfo.getPeerPublicKey()
        let nonce = serverEncoderInfo.getNonce()
        let personal = serverEncoderInfo.getPersonalization()
        
        // Display all info related to server Encoder.
        print("\nServer Encoder public key:")
        print(publicKey.bytesToHex())
        print("\nServer Encoder peer's key:")
        print(peerKey.bytesToHex())
        print("\nServer Encoder nonce:")
        print(nonce.bytesToHex())
        print("\nServer Encoder personalization:")
        print(String(bytes:personal, encoding: .utf8) ?? "")
        
        // Set Encoder nonce.
        encoder.setNonce(nonce)
        
        do {
            // Create shared secret.
            var secret = try serverEncoderInfo.getSharedSecret()
            
            // Set Encoder entropy using this shared secret.
            encoder.setEntropy(&secret)
        } catch  {
            print("Error attempting to create shared secret.")
            return false
        }
        
        // Instantiate Encoder.
        let status = encoder.instantiate(personal)
        if status != mte_status_success {
            print("Encoder Instantiate error (\(MteBase.getStatusName(status))): " +
                  MteBase.getStatusDescription(status))
            return false
        }
        
        return true
    }
    
    public func createDecoder() -> Bool {
        let publicKey = serverDecoderInfo.getPublicKey()
        let peerKey = serverDecoderInfo.getPeerPublicKey()
        let nonce = serverDecoderInfo.getNonce()
        let personal = serverDecoderInfo.getPersonalization()
        
        // Display all info related to server Decoder.
        print("\nServer Decoder public key:")
        print(publicKey.bytesToHex())
        print("\nServer Decoder peer's key:")
        print(peerKey.bytesToHex())
        print("\nServer Decoder nonce:")
        print(nonce.bytesToHex())
        print("\nServer Decoder personalization:")
        print(String(bytes:personal, encoding: .utf8) ?? "")
        
        // Set Decoder nonce.
        decoder.setNonce(nonce)
        
        do {
            // Create shared secret.
            var secret = try serverDecoderInfo.getSharedSecret()
            
            // Set Decoder entropy using this shared secret.
            decoder.setEntropy(&secret)
        } catch  {
            print("Error attempting to create shared secret.")
            return false
        }
        
        // Instantiate Decoder.
        let status = decoder.instantiate(personal)
        if status != mte_status_success {
            print("Decoder Instantiate error (\(MteBase.getStatusName(status))): " +
                  MteBase.getStatusDescription(status))
            return false
        }
        
        return true
    }
    
    // =================
    // Step 5 - Encoding
    // =================
    public func encodeMessage(message:[uint8], encoded:inout [uint8]) -> Bool {
        // Display original message.
        print("\nMessage to be encoded")
        print(String(bytes:message, encoding: .utf8) ?? "")
        
        // Encode the message.
        let encodedMessage = encoder.encode(message)
        // Ensure that it encoded successfully.
        if encodedMessage.status != mte_status_success {
            print("Error encoding (\(MteBase.getStatusName(encodedMessage.status))): " +
                  MteBase.getStatusDescription(encodedMessage.status))
            return false
        }
        
        encoded = Array(encodedMessage.encoded)
        // Display encoded message.
        print("Encoded message being sent:\n (\(encoded))")
        
        return true
    }
    
    // =================
    // Step 6 - Decoding
    // =================
    public func decodeMessage(encoded:[uint8], decoded:inout [uint8]) -> Bool {
        // Display encoded message.
        print("Encoded message being sent:\n (\(encoded))")
        
        // Decode the encoded message.
        let decodedMessage = decoder.decode(encoded)
        
        // Ensure that there were no decoding errors.
        if MteBase.statusIsError(decodedMessage.status) {
            print("Error decoding (\(MteBase.getStatusName(decodedMessage.status))): " +
                  MteBase.getStatusDescription(decodedMessage.status))
            return false
        }
        
        // Set decoded message.
        decoded = Array(decodedMessage.decoded)
        
        // Remove any null terminator byte.
        while let i = decoded.firstIndex(of:0) {
            decoded.remove(at: i)
        }
        
        // Display decoded message.
        print("\nDecoded message")
        print(String(bytes:decoded, encoding: .utf8) ?? "")
        return true
    }
    
    // =================
    // Step 7 - Clean Up
    // =================
    public func finishMte() {
        // Uninstantiate Encoder and Decoder.
        _ = encoder.uninstantiate()
        _ = decoder.uninstantiate()
    }
}

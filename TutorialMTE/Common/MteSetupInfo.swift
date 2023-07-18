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

public class MteSetupInfo {
    private var ecdhManager: EcdhP256
    private var personalization: [uint8]? = nil
    private var nonce: [uint8]? = nil
    private var publicKey: [uint8]? = nil
    private var peerKey: [uint8]? = nil
    
    struct Err: Error {
        let status: Int
    }
    
    public init() throws {
        ecdhManager = EcdhP256(name: "")
        
        // Create the private and public keys.
        let res: (status:Int, publicKey:[uint8]?) = ecdhManager.createKeyPair()
        if (res.status < 0) {
            throw Err(status: res.status)
        }
        
        publicKey = res.publicKey
    }
    
    deinit {
        // Zeroize public key.
        EcdhP256.zeroize(&publicKey!)
    }
    
    public func getPublicKey() -> [uint8] {
        // Create copy of public key.
        let temp:[uint8] = publicKey ?? []
        return temp
    }
    
    public func getSharedSecret() throws -> [uint8] {
        // Check peer key size.
        if peerKey?.count == 0 {
            throw Err(status: EcdhP256.ResultCodes.memoryFail)
        }
        
        // Create temp array.
        var temp:[uint8] = []
        
        let res = ecdhManager.getSharedSecret(peerPublicKey: peerKey!, secret: &temp)
        if res < 0 {
            throw Err(status: EcdhP256.ResultCodes.memoryFail)
        }
        
        return temp
    }
    
    public func setPersonalization(data:[uint8]) {
        personalization = data
    }
    
    public func getPersonalization() -> [uint8] {
        if personalization != nil {
            return personalization!
        } else {
            return []
        }
    }
    
    public func setNonce(data:[uint8]) {
        nonce = data
    }
    
    public func getNonce() -> [uint8] {
        if nonce != nil {
            return nonce!
        } else {
            return []
        }
    }
    
    public func setPeerPublicKey(data:[uint8]) {
        peerKey = data
    }
    
    public func getPeerPublicKey() -> [uint8] {
        if peerKey != nil {
            return peerKey!
        } else {
            return []
        }
    }
}

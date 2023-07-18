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

// This tutorial uses Sockets for communication.
// It should be noted that the MTE can be used with any type of communication. (SOCKETS are not required!).

// Display program information.
displayProgramInfo()

// Set port
print("Please enter port to use, press Enter to use default \(Settings.port):")
var portStr = readLine(strippingNewline: true)

// Init manager.
let manager = Main(port: UInt16(portStr!) ?? Settings.port)

func displayProgramInfo() {
    // Display the language and application.
    print("Starting Swift Socket Server.")
    
#if USE_MTE_CORE
    let mteType = "Core"
#endif
#if USE_MKE_ADDON
    let mteType = "MKE"
#endif
#if USE_FLEN_ADDON
    let mteType = "Flen"
#endif
    
    print("Using MTE Version: \(MteBase.getVersion())-\(mteType)")
}

protocol SocketManagerDelegate: AnyObject {
    func didReceiveMessage(header:Character, data:[uint8])
}

// The states the manager become.
public enum state {
    case ready
    case fromClient
    case toClient
    case diagnostic
    case mainLoop
    case error
}

class Main:SocketManagerDelegate {
    var mteInfo = [String:[uint8]]()
    var mteHelper:ServerMteHelper!
    var socketManager:ServerSocketManager!
    
    // Set state to initial ready state.
    var managerState: state = state.ready
    
    init(port: UInt16) {
        socketManager = ServerSocketManager(port: port)
        socketManager.delegate = self
        do {
            mteHelper = try ServerMteHelper()
            
            managerState = state.fromClient
            
            // Start to receive info from client.
            try socketManager.start()
        } catch {
            print (error)
            exit(EXIT_FAILURE)
        }
        
        // End the program.
        closeProgram()
    }
    
    func sendMessage(message:[uint8]) -> Bool {
        // Encode the message.
        var encoded: [uint8] = []
        if !mteHelper.encodeMessage(message: message, encoded: &encoded) {
            return false
        }
        
        // Send the encoded message.
        socketManager.sendMessage(header: "m", message: encoded)
        
        return true
    }
    
    func didReceiveMessage(header: Character, data: [uint8]) {
        // Determine what to do with message based on current manager state.
        switch (managerState) {
        case state.fromClient:
            // Info from client.
            // Exchange entropy, nonce, and personalization string between the client and server.
            getInfoFromClient(header: header, data: data)
            break
        case state.toClient:
            // Received an ack from client.
            
            // Set state to now run diagnostic test.
            managerState = state.diagnostic
            
            // Create Encoder and Decoder.
            createEncoderAndDecoder()
            
            break
        case state.diagnostic:
            runDiagnosticTest(header: header, data: data)
            break
        case state.mainLoop:
            handleMainLoop(header: header, data: data)
            break
        default:
            break
        }
    }
    
    // =============================
    // Step 3 - Information Exchange
    // =============================
    func getInfoFromClient(header: Character, data: [uint8]) {
        // The client Encoder and the server Decoder will be paired.
        // The client Decoder and the server Encoder will be paired.
        
        // Evaluate the header.
        // 1 - server Decoder public key (from client Encoder)
        // 2 - server Decoder personalization string (from client Encoder)
        // 3 - server Encoder public key (from client Decoder)
        // 4 - server Encoder personalization string (from client Decoder)
        switch (header) {
        case "1":
            if (mteHelper.getDecoderPeerKey().count == 0) {
            }
            mteHelper.setDecoderPeerKey(data: data)
            break
        case "2":
            if (mteHelper.getDecoderPersonal().count == 0) {
            }
            mteHelper.setDecoderPersonal(data: data)
            break
        case "3":
            if (mteHelper.getEncoderPeerKey().count == 0) {
            }
            mteHelper.setEncoderPeerKey(data: data)
            break
        case "4":
            if (mteHelper.getEncoderPersonal().count == 0) {
            }
            mteHelper.setEncoderPersonal(data: data)
            break
        default:
            managerState = state.error
            // Unknown message, abort here, send an 'E' for error.
            socketManager.sendMessage(header: "E", message: Array("ERR".utf8))
        }
        
        // Continue to receive data until all MTE information has been received.
        if !mteHelper.hasReceivedAllMteInfo() {
            socketManager.receiveMessage()
        } else {
            // Now all values from client have been received, send an 'A' for acknowledge to client.
            socketManager.sendMessage(header: "A", message: Array("ACK".utf8))
            
            // Now this will start to send info to the client.
            managerState = state.toClient
            
            sendInfoToClient()
        }
        
    }
    
    func sendInfoToClient() {
        // Prepare to send server information now.
        
        // Create nonces.
        let timestamp:uint64 = ServerMteHelper.getTimestamp()
        
        var encNonce = withUnsafeBytes(of: timestamp.bigEndian) {
            Array($0)
        }
        
        // Insert '0's at beginning of array to fill it up to 16 items.
        while (encNonce.count < 16) {
            encNonce.insert(0, at: 0)
        }
        
        mteHelper.setEncoderNonce(data: encNonce)
        
        // For Decoder, reverse the bytes in the byte array.
        var decNonce = withUnsafeBytes(of: timestamp.littleEndian) {
            Array($0)
        }
        
        // Insert '0's at end of array to fill it up to 16 items.
        while (decNonce.count < 16) {
            decNonce.append(0)
        }
        
        mteHelper.setDecoderNonce(data: decNonce)
        
        // Send out information to the client.
        // 1 - server Encoder public key (to client Decoder)
        // 2 - server Encoder nonce (to client Decoder)
        // 3 - server Decoder public key (to client Encoder)
        // 4 - server Decoder nonce (to client Encoder)
        socketManager.sendMessage(header: "1", message: mteHelper.getEncoderPublicKey())
        socketManager.sendMessage(header: "2", message: mteHelper.getEncoderNonce())
        socketManager.sendMessage(header: "3", message: mteHelper.getDecoderPublicKey())
        socketManager.sendMessage(header: "4", message: mteHelper.getDecoderNonce())
        
        // Wait for next message.
        socketManager.receiveMessage()
    }
    
    func createEncoderAndDecoder() {
        // Create Decoder.
        if !mteHelper.createDecoder() {
            exit(EXIT_FAILURE)
        }
        
        // Create Encoder.
        if !mteHelper.createEncoder() {
            exit(EXIT_FAILURE)
        }
        
        socketManager.receiveMessage()
    }
    
    func runDiagnosticTest(header: Character, data: [uint8]) {
        // Decode the message.
        var decoded:[uint8] = []
        if !mteHelper.decodeMessage(encoded: data, decoded: &decoded) {
            exit(EXIT_FAILURE)
        }
        
        // Check that it successfully decoded as "ping".
        if "ping" == String(bytes: decoded, encoding: .utf8) {
            print("Server Decoder decoded the message from the client Encoder successfully.\n")
        } else {
            print("Server Decoder DID NOT decode the message from the client Encoder successfully.\n")
            exit(EXIT_FAILURE)
        }
        
        // Create "ack" message.
        let message:[uint8] = Array("ack".utf8)
        
        // Encode and send message.
        if !sendMessage(message: message) {
            exit(EXIT_FAILURE)
        }
        
        // Change state to be for main loop.
        managerState = state.mainLoop
        
        // Get next message.
        socketManager.receiveMessage()
    }
    
    func handleMainLoop(header: Character, data: [uint8]) {
        // Decode the message.
        var decoded:[uint8] = []
        if !mteHelper.decodeMessage(encoded: data, decoded: &decoded) {
            exit(EXIT_FAILURE)
        }
        
        // Encode and send message.
        if !sendMessage(message: decoded) {
            exit(EXIT_FAILURE)
        }
        
        // Get next message.
        socketManager.receiveMessage()
    }
    
    func closeProgram() {
        print("Program stopped.")
    }
    
}

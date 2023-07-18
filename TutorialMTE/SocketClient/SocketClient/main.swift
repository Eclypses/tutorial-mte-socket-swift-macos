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

// Set ipAddress
print("Please enter ip address of Server, press Enter to use default \(Settings.ipAddress):")
var ipAddress = readLine(strippingNewline: true)
if ipAddress == "" {
    ipAddress = Settings.ipAddress
}

// Set port
print("Please enter port to use, press Enter to use default \(Settings.port):")
var portStr = readLine(strippingNewline: true)

// Init manager.
let manager = Main(ipAddress: ipAddress ?? Settings.ipAddress, port: UInt16(portStr!) ?? Settings.port)

func displayProgramInfo() {
    // Display the language and application.
    print("Starting Swift Socket Client.")
    
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
    func sendInfoToServer()
}

// The states the manager can be in.
public enum state {
    case ready
    case toServer
    case fromServer
    case diagnostic
    case mainLoop
    case error
}

class Main:SocketManagerDelegate {
    var mteInfo = [String:[uint8]]()
    var mteHelper:ClientMteHelper!
    var socketManager:ClientSocketManager!
    var input:String = ""
    
    // Set state to initial ready state.
    var managerState: state = state.ready
    
    init(ipAddress: String, port: UInt16) {
        socketManager = ClientSocketManager(ipAddress: ipAddress, port: port)
        socketManager.delegate = self
        do {
            mteHelper = try ClientMteHelper()
            
            managerState = state.toServer
            
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
        case state.toServer:
            managerState = state.fromServer
            socketManager.receiveMessage()
        case state.fromServer:
            getInfoFromServer(header: header, data: data)
            
            break
        case state.diagnostic:
            receiveDiagnosticTest(header: header, data: data)
            break
        case state.mainLoop:
            receiveFromServer(header: header, data: data)
            break
        default:
            break
        }
        
    }
    
    // =============================
    // Step 3 - Information Exchange
    // =============================
    func sendInfoToServer() {
        // The client Encoder and the server Decoder will be paired.
        // The client Decoder and the server Encoder will be paired.
        
        // Prepare to send client information.
        // Create personalization strings.
        let clientEncoderPersonal = UUID().uuidString
        mteHelper.setEncoderPersonal(data: Array(clientEncoderPersonal.utf8))
        
        let clientDecoderPersonal = UUID().uuidString
        mteHelper.setDecoderPersonal(data: Array(clientDecoderPersonal.utf8))
        
        // Send out information to the server.
        // 1 - client Encoder public key (to server Decoder)
        // 2 - client Encoder personalization string (to server Decoder)
        // 3 - client Decoder public key (to server Encoder)
        // 4 - client Decoder personalization string (to server Encoder)
        socketManager.sendMessage(header: "1", message: mteHelper.getEncoderPublicKey())
        socketManager.sendMessage(header: "2", message: mteHelper.getEncoderPersonal())
        socketManager.sendMessage(header: "3", message: mteHelper.getDecoderPublicKey())
        socketManager.sendMessage(header: "4", message: mteHelper.getDecoderPersonal())
        
        // Wait for next message.
        socketManager.receiveMessage()
        
    }
    
    func getInfoFromServer(header: Character, data: [uint8]) {
        
        // Evaluate the header.
        // 1 - client Decoder public key (from server Encoder)
        // 2 - client Decoder nonce (from server Encoder)
        // 3 - client Encoder public key (from server Decoder)
        // 4 - client Encoder nonce (from server Decoder)
        switch (header) {
        case "1":
            if (mteHelper.getDecoderPeerKey().count == 0) {
            }
            mteHelper.setDecoderPeerKey(data: data)
            break
        case "2":
            if (mteHelper.getDecoderNonce().count == 0) {
            }
            mteHelper.setDecoderNonce(data: data)
            break
        case "3":
            if (mteHelper.getEncoderPeerKey().count == 0) {
            }
            mteHelper.setEncoderPeerKey(data: data)
            break
        case "4":
            if (mteHelper.getEncoderNonce().count == 0) {
            }
            mteHelper.setEncoderNonce(data: data)
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
            // Now all values from server have been received, send an 'A' for acknowledge to server.
            socketManager.sendMessage(header: "A", message: Array("ACK".utf8))
            
            // Create Encoder and Decoder.
            createEncoderAndDecoder()
            
        }
    }
    
    func createEncoderAndDecoder() {
        // Create Encoder.
        if !mteHelper.createEncoder() {
            exit(EXIT_FAILURE)
        }
        
        // Create Decoder.
        if !mteHelper.createDecoder() {
            exit(EXIT_FAILURE)
        }
        
        // Start the diagnostic test.
        sendDiagnosticTest()
    }
    
    func sendDiagnosticTest() {
        // Create "ping" message.
        let message:[uint8] = Array("ping".utf8)
        
        // Encode and send message.
        if !sendMessage(message: message) {
            exit(EXIT_FAILURE)
        }
        
        managerState = state.diagnostic
        
        socketManager.receiveMessage()
    }
    
    func receiveDiagnosticTest(header: Character, data: [uint8]) {
        // Decode the message.
        var decoded:[uint8] = []
        if !mteHelper.decodeMessage(encoded: data, decoded: &decoded) {
            exit(EXIT_FAILURE)
        }
        
        // Check that it successfully decoded as "ack".
        if "ack" == String(bytes: decoded, encoding: .utf8) {
            print("Client Decoder decoded the message from the server Encoder successfully.\n")
        } else {
            print("Client Decoder DID NOT decode the message from the server Encoder successfully.\n")
            exit(EXIT_FAILURE)
        }
        
        // Start to get input from user.
        managerState = state.mainLoop
        
        sendUserInputToServer()
    }
    
    func sendUserInputToServer() {
        // Prompt user for input to send to other side.
        
        print("Please enter up to \(Settings.maxInputBytes) bytes to send: (To end please type 'quit')\n")
        input = readLine(strippingNewline: true) ?? ""
        if input.isEmpty || input.lowercased() == "quit" {
            closeProgram()
        }
        
        // Encode and send message.
        if !sendMessage(message: [UInt8](input.utf8)) {
            exit(EXIT_FAILURE)
        }
        
        // Wait for return message.
        socketManager.receiveMessage()
    }
    
    func receiveFromServer(header: Character, data: [uint8]) {
        // Decode the message.
        var decoded:[uint8] = []
        if !mteHelper.decodeMessage(encoded: data, decoded: &decoded) {
            exit(EXIT_FAILURE)
        }
        
        // Compare the decoded message to the original.
        if input == String(bytes: decoded, encoding: .utf8) {
            print("The original input and decoded return match.\n")
        } else {
            print("The original input and decoded return DO NOT match.\n")
            exit(EXIT_FAILURE)
        }
        
        // Get the next input.
        sendUserInputToServer()
    }
    
    func closeProgram() {
        print("Program stopped.")
        socketManager.stop(error: nil)
    }
}

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
import Network

//MARK: MTE Properties

/* Step 7 */
//---------------------------------------------------
// MKE and Fixed length add-ons are NOT in all SDK
// MTE versions. If the name of the SDK includes
// "-MKE" then it will contain the MKE add-on. If the
// name of the SDK includes "-FLEN" then it contains
// the Fixed length add-on.
//---------------------------------------------------
// Create the Mte encoder, uncomment to use MTE core
//---------------------------------------------------
var encoder: MteEnc!
encoder = try MteEnc()
var mteType = "Core"
//---------------------------------------------------
// Create the Mte MKE encoder, uncomment to use MMK
//---------------------------------------------------
//var encoder: MteMkeEnc!
//encoder = try MteMkeEnc()
//var mteType = "MKE"
//---------------------------------------------------
// Create the Fixed length encoder, uncomment to use MTE FLEN
//---------------------------------------------------
//var encoder: MteFlenEnc!
//let fixedBytes = 8
//encoder = try MteFlenEnc(fixedBytes)
//var mteType = "FLEN"

var encoderStatus: mte_status

//---------------------------------------------------
// Create the MTE decoder, uncomment to use MTE core OR FLEN
// Create the Mte Fixed length decoder (SAME as MTE Core)
//---------------------------------------------------
var decoder: MteDec!
decoder = try MteDec()
//---------------------------------------------------
// Create the Mte MKE decoder, uncomment to use MKE
//---------------------------------------------------
//var decoder: MteMkeDec!
//decoder = try MteMkeDec()

var decoderStatus: mte_status
print("Starting Swift Socket Server.")
print("Using MTE Version: \(MteBase.getVersion())-\(mteType)")

let ipv4Addresses = getipv4Addresses()
print("Server will listen on \(ipv4Addresses[0])")

// Set port
print("Please enter port to use, press Enter to use default \(Settings.port):")
var portStr = readLine(strippingNewline: true)
let port = portStr != ""  ? UInt16(portStr!) : Settings.port

/* Step 8 */


// OPTIONAL!!! adding 1 to decoder nonce so return value changes -- same nonce can be used for encoder and decoder
// on client side values will be switched so they match up encoder to decoder and vice versa
var encoderNonce: UInt64 = 0
var decoderNonce: UInt64 = 1

var personalizationString: String = "demo"

/* Step 9 */
// Check mte license
if !MteBase.initLicense("LicenseCompanyName", "LicenseKey") {
    print("There was an error attempting to initialize the MTE license.")
    exit(EXIT_FAILURE)
}

// MARK: MTE Setup

/* Step 10 */
// Initialize Encoder

// IMPORTANT! ** This is an entirely insecure way of setting Entropy and MUST NEVER be used in a "real"
// application. Please see MTE Developer's Guide for more information.
// Create 'all-zero' entropy for this tutorial.
var entropy: [UInt8]!

let entropyBytes = MteBase.getDrbgsEntropyMinBytes(encoder.getDrbg())
entropy = [UInt8](repeating: Character("0").asciiValue!, count: entropyBytes)

encoder.setEntropy(&entropy)
encoder.setNonce(encoderNonce)
encoderStatus = encoder.instantiate([UInt8](personalizationString.utf8))
if encoderStatus != mte_status_success {
    print("Encoder Instantiate error (\(MteBase.getStatusName(encoderStatus))): " +
          MteBase.getStatusDescription(encoderStatus))
    exit(EXIT_FAILURE)
}

// Initialize Decoder

// When entropy is set in the encoder, it is zeroized, therefore, we need to 'refill' it before setting in decoder
// IMPORTANT! ** As stated above, this is an entirely insecure way of setting the entropy
// parameter and MUST NEVER be used in a real application.
entropy = [UInt8](repeating: Character("0").asciiValue!, count: entropyBytes)

decoder.setEntropy(&entropy)
decoder.setNonce(decoderNonce)
decoderStatus = decoder.instantiate([UInt8](personalizationString.utf8))
if decoderStatus != mte_status_success {
    print("Decoder Instantiate error (\(MteBase.getStatusName(decoderStatus))): " +
          MteBase.getStatusDescription(decoderStatus))
    exit(EXIT_FAILURE)
}

// MARK: Socket Setup
// Initialize variables
let nwPort: NWEndpoint.Port = NWEndpoint.Port(rawValue: port!)!
let listener: NWListener = try! NWListener(using: .tcp, on: nwPort)
var connection: NWConnection!

// Start Server
listener.stateUpdateHandler = listenerStateDidChange(to:)
listener.newConnectionHandler = listenerDidAcceptConnection(nwConnection:)
listener.start(queue: .main)

RunLoop.current.run()

private func listenerDidAcceptConnection(nwConnection: NWConnection) {
    connection = nwConnection
    connection.stateUpdateHandler = connectionStateDidChange(to:)
    connection.start(queue: .main)
    listener.cancel()
}

func listenForClientMessage() {
    receive()
}

func receive() {
    print("\nListening for messages from Client . . .\n")
    connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, _, isComplete, error) in
        if isComplete {
            connectionDidEnd()
            return
        } else if let error = error {
            connectionDidFail(error: error)
            return
        }
        guard let data = data, !data.isEmpty else {
            print("Received no length prefix data")
            exit(EXIT_FAILURE)
        }
        
        // Retrieve the length of the incoming data in Big Endian format
        let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian}
        
        // Receive the Server response data
        connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { (data, _, isComplete, error) in
            guard let data = data, !data.isEmpty else {
                print("Received no message data")
                exit(EXIT_FAILURE)
            }
            print("Base64 encoded representation of the received packet: \n\(data.bytes.UTF8toBase64())")
            
            /* Step 11 */
            // Decode the incoming data.
            let decodedResult = decoder.decode(data.bytes)
            if decodedResult.status != mte_status_success {
                print("Error decoding: Status: (\(MteBase.getStatusName(decodedResult.status)))/ " +
                      MteBase.getStatusDescription(decodedResult.status))
                exit(EXIT_FAILURE)
            }
            guard let decodedText = String(bytes: decodedResult.decoded, encoding: .utf8) else {
                print("Unable to retrieve text string from data")
                return
            }
            
            print("Decoded data: \n\(decodedText)")
            // Echo back to Client. Data will be re-encoded in send() function
            send(data: [UInt8](decodedResult.decoded))
        }
    }
}

func send(data: [UInt8]) {
    
    /* Step 11 */
    // Encode the data with MTE
    let encodedResult = encoder.encode(data)
    if encodedResult.status != mte_status_success {
        print("Error encoding: Status: (\(MteBase.getStatusName(encodedResult.status)))/ " +
              MteBase.getStatusDescription(encodedResult.status))
        exit(EXIT_FAILURE)
    }
    print("Base64 encoded representation of the packet being sent: \n\(Array(encodedResult.encoded).UTF8toBase64())")
    
    // Send the data length first in big endian format
    let length = Int32(encodedResult.encoded.count)
    let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
    connection.send(content: dataLength, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            return
        }
    }))
    
    // Then send the encoded data
    connection.send(content: encodedResult.encoded, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            exit(EXIT_FAILURE)
        }
        listenForClientMessage()
    }))
}

func listenerStateDidChange(to newState: NWListener.State) {
    switch newState {
    case .ready:
        print("Listening for new Client connection . . .\n")
    case .failed(let error):
        print("Listener failure, error: \(error.localizedDescription)")
        exit(EXIT_FAILURE)
    default:
        break
    }
}

private func connectionStateDidChange(to state: NWConnection.State) {
    
    switch state {
    case .waiting(let error):
        connectionDidFail(error: error)
    case .ready:
        print("Connected with Client")
        print("Socket Server is listening on \(ipv4Addresses[0])")
        listenForClientMessage()
    case .failed(let error):
        connectionDidFail(error: error)
    default:
        break
    }
}

func stop() {
    print("Program stopped.")
}

private func connectionDidFail(error: Error) {
    print("Connection with Client did fail, error: \(error)")
    stop(error: error)
}

private func connectionDidEnd() {
    print("Connection closed.")
    stop(error: nil)
}

private func stop(error: Error?) {
    connection.stateUpdateHandler = nil
    connection.cancel()
    exit(EXIT_SUCCESS)
}

enum EncDecType {
    case core, mke, flen
}


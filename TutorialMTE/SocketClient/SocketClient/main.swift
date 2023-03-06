//
// ****************************************************************
// SocketClient
// main.swift created on 3/22/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

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
print("Starting Swift Socket Client.")
print("Using MTE Version: \(MteBase.getVersion())-\(mteType)")

// Set ipAddress
print("Please enter ip address of Server, press Enter to use default \(Settings.ipAddress):")
var ipAddress = readLine(strippingNewline: true)
if ipAddress == "" {
    ipAddress = Settings.ipAddress
}
print("Server is at \(ipAddress!)")

// Set port
print("Please enter port to use, press Enter to use default \(Settings.port):")
var portStr = readLine(strippingNewline: true)
let port = portStr != ""  ? UInt16(portStr!) : Settings.port

/* Step 8 */

// In this tutorial, we set the encoder and decoder nonces differently so the encoded payloads will appear different
// even though the data prior to encoding is the same. They are reversed on the Client so they match up with
// the Server
var encoderNonce: UInt64 = 1
var decoderNonce: UInt64 = 0

/* Step 9 */
// Check mte license
if !MteBase.initLicense("LicenseCompanyName", "LicenseKey") {
    print("There was an error attempting to initialize the MTE license.")
    exit(EXIT_FAILURE)
}

var personalizationString: String = "demo"

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
// When entropy is set in the encoder, it is zeroized out, therefore, we need to 'refill' it before setting in decoder
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

let nwHost = NWEndpoint.Host(ipAddress!)
let nwPort = NWEndpoint.Port(rawValue: port!)!
let nwConnection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
let queue = DispatchQueue(label: "Client connection Q")

nwConnection.stateUpdateHandler = stateDidChange(to:)
nwConnection.start(queue: queue)
var command: String?

func listenForUserInput() {
    print("Please enter text to send: (To end please type 'quit')")
    command = readLine(strippingNewline: true)
    if command!.lowercased() == "quit" {
        stop()
    }
    send(data: [UInt8](command!.utf8))
}

RunLoop.current.run()

func send(data: [UInt8]) {
    
    /* Step 11 */
    // Use MTE to encode the data
    let encodedResult = encoder.encode(data)
    if encodedResult.status != mte_status_success {
        print("Error encoding: Status (\(MteBase.getStatusName(encodedResult.status)))/ " +
              MteBase.getStatusDescription(encodedResult.status))
        exit(EXIT_FAILURE)
    }
    
    // Send the length first
    let length = Int32(encodedResult.encoded.count)
    let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
    
    // Send the data length first . . .
    nwConnection.send(content: dataLength, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
        }
    }))
    
    // Then, send the encoded data
    nwConnection.send(content: encodedResult.encoded, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            return
        }
        //
        // For demonstration purposes only to show packets.
        print("Base64 encoded representation of the packet being sent: \n\(Array(encodedResult.encoded).UTF8toBase64())")
        receive()
    }))
}

private func receive() {
    nwConnection.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, _, isComplete, error) in
        if isComplete {
            connectionDidEnd()
        } else if let error = error {
            connectionDidFail(error: error)
        }
        guard let data = data, !data.isEmpty else {
            print("Received no length prefix data")
            exit(EXIT_FAILURE)
        }
        
        // Retrieve the length of the incoming data in Big Endian format
        let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian}
        
        // Receive the Server response data
        nwConnection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { (data, _, isComplete, error) in
            guard let data = data, !data.isEmpty else {
                print("Received no message data")
                exit(EXIT_FAILURE)
            }
            print("Base64 encoded representation of the received packet: \n\(data.bytes.UTF8toBase64())")
            
            /* Step 11 */
            // Decode the incoming data.
            let decodedResult = decoder.decode(data.bytes)
            if decodedResult.status != mte_status_success {
                print("Error decoding: Status (\(MteBase.getStatusName(decodedResult.status)))/" +
                      MteBase.getStatusDescription(decodedResult.status))
                exit(EXIT_FAILURE)
            }
            
            print("Received MTE packet: \n\(data.bytes.UTF8toBase64())")
            
            listenForUserInput()
        }
    }
}

private func stateDidChange(to state: NWConnection.State) {
    switch state {
    case .waiting(let error):
        connectionDidFail(error: error)
    case .ready:
        print("Client connected to Server.")
        listenForUserInput()
    case .failed(let error):
        connectionDidFail(error: error)
    default:
        break
    }
}

func stop() {
    print("Program stopped.")
    stop(error: nil)
}

private func connectionDidFail(error: Error) {
    print("Connection with Server did fail, error: \(error)")
    stop(error: error)
}

private func connectionDidEnd() {
    print("Connection closed.")
    stop(error: nil)
}

private func stop(error: Error?) {
    nwConnection.stateUpdateHandler = nil
    nwConnection.cancel()
    exit(EXIT_SUCCESS)
}

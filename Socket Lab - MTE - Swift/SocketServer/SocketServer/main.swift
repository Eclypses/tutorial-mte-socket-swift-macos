//
// ****************************************************************
// SocketServer
// main.swift created on 3/22/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

import Foundation
import Network

print("Starting Swift Socket Server using MTE Version \(MteBase.getVersion())")

let ipv4Addresses = getipv4Addresses()
print("Server will listen on \(ipv4Addresses[0])")

// Set port
print("Type Server port or hit [ENTER] for \(Settings.port)")
var portStr = readLine(strippingNewline: true)
let port = portStr != ""  ? UInt16(portStr!) : Settings.port
print("Server port is: \(port!)")

//MARK: MTE Properties

// Status
var status: mte_status!

var encoder: MteEnc!
var decoder: MteDec!

// In this Lab, we set the encoder and decoder nonces differently so the encoded payloads will appear different
// even though the data prior to encoding is the same. They are reversed on the Client so they match up with
// the Server
var encoderNonce: UInt64 = 0
var decoderNonce: UInt64 = 1

// Options
var drbg: mte_drbgs = mte_drbgs_ctr_aes256_df
var tokenBytes: Int = 8 // Number of payload bytes each packet byte is expanded to.
var byteValMin: Int = 0
var byteValCount: Int = 256
var verifier: mte_verifiers = mte_verifiers_none
let timeStampWindow: UInt64 = 1 // number of seconds in-transit permitted if timestamp verification is turned on.
let sequenceWindow: Int = 0 // number of dropped packets permitted if sequencing verification is turned on.

// Check mte license
if !MteBase.initLicense("LicenseCompanyName", "LicenseKey") {
    print("MTE License Check ERROR (\(MteBase.getStatusName(status))): " +
            MteBase.getStatusDescription(status))
    exit(EXIT_FAILURE)
} else {
    print("MTE License Check SUCCESS")
}

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
status = MteBase.drbgsSelfTest(drbg)
if status != mte_status_success {
    print("DRBG SelfTest ERROR (\(MteBase.getStatusName(status))): " +
            MteBase.getStatusDescription(status))
    exit(EXIT_FAILURE)
} else {
    print("DRBG SelfTest SUCCESS")
}

// IMPORTANT! ** This is an entirely insecure way of setting Entropy and MUST NOT be used in a "real"
// application. PLease see MTE Developer's Guide for more information.
// Create all-zero entropy for this lab.
let entropyBytes = MteBase.getDrbgsEntropyMinBytes(drbg)
var entropy = [UInt8](repeating: 0, count: entropyBytes)

var personalizationString: String = "demo"

// MARK: MTE Setup

// Initialize Encoder
do {
    encoder = try MteEnc(drbg, tokenBytes, byteValMin, byteValCount, verifier)
    encoder.setEntropy(entropy)
    encoder.setNonce(encoderNonce)
    status = encoder.instantiate([UInt8](personalizationString.utf8))
    if status != mte_status_success {
        print("Encoder Instantiate error (\(MteBase.getStatusName(status))): " +
                MteBase.getStatusDescription(status))
        exit(EXIT_FAILURE)
    } else {
        print("Encoder Instantiate SUCCESS")
    }
} catch {
    print("Exception in Encoder. Error: \(error.localizedDescription)")
    exit(EXIT_FAILURE)
}

// Initialize Decoder
do {
    decoder = try MteDec(drbg, tokenBytes, byteValMin, byteValCount, verifier, timeStampWindow, sequenceWindow)
    decoder.setEntropy(entropy)
    decoder.setNonce(decoderNonce)
    status = decoder.instantiate([UInt8](personalizationString.utf8))
    if status != mte_status_success {
        print("Decoder Instantiate error (\(MteBase.getStatusName(status))): " +
                MteBase.getStatusDescription(status))
        exit(EXIT_FAILURE)
    } else {
        print("Decoder Instantiate SUCCESS")
    }
} catch {
    print("Exception in Decoder. Error: \(error.localizedDescription)")
    exit(EXIT_FAILURE)
}

// Because entropy in this lab is already all zeros of the minimum entropy length required by the drbg, this is
// not strictly necessary but is included here to demonstrate best-practice.
// Zero out the entropy
entropy = [UInt8](repeating: 0, count: entropy.count)

print("MTE Setup SUCCESS. \n\nSetting up Server")

// MARK: Socket Setup
// Initialize variables
let nwPort: NWEndpoint.Port = NWEndpoint.Port(rawValue: port!)!
let listener: NWListener = try! NWListener(using: .tcp, on: nwPort)
var connection: NWConnection!

// Start Server
listener.stateUpdateHandler = listenerStateDidChange(to:)
listener.newConnectionHandler = listenerDidAcceptConnection(nwConnection:)
listener.start(queue: .main)
print("Server started . . . ")

RunLoop.current.run()



private func listenerDidAcceptConnection(nwConnection: NWConnection) {
    connection = nwConnection
    connection.stateUpdateHandler = connectionStateDidChange(to:)
    connection.start(queue: .main)
    print("Master_Socket on port \(port!) closed. No new connections will be accepted during this session.")
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
            print("Encoded message from client (as Ascii Hex only for display here): \n\t\(data.bytes.bytesToHex())")
            
            // Decode the incoming data with MTE
            let decodeResult = decoder.decode(data.bytes)
            if decodeResult.status != mte_status_success {
                print("MTE decode ERROR (\(MteBase.getStatusName(decodeResult.status))): " +
                        MteBase.getStatusDescription(decodeResult.status))
                exit(EXIT_FAILURE)
            }
            guard let message = String(bytes: decodeResult.decoded, encoding: .utf8) else {
                print("Unable to retrieve text string from data")
                return
            }
            print("Decoded Message: \n\t\(message)")
            
            // Echo back to Client. Data will be re-encoded in send() function
            send(data: decodeResult.decoded)
        }
    }
}

func send(data: [UInt8]) {
    
    // Encode the data with MTE
    let encodeResult = encoder.encode(data)
    if encodeResult.status != mte_status_success {
        print("MTE encode ERROR (\(MteBase.getStatusName(encodeResult.status))): " +
                MteBase.getStatusDescription(encodeResult.status))
        exit(EXIT_FAILURE)
    }
    print("Encoded response data (as Ascii Hex only for display here): \n\t\(encodeResult.encoded.bytesToHex())")
    
    // Send the data length first in big endian format
    let length = Int32(encodeResult.encoded.count)
    let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
    connection.send(content: dataLength, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            return
        }
    }))
    
    // Then send the encoded data
    connection.send(content: encodeResult.encoded, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            exit(EXIT_FAILURE)
        }
        print("Response sent successfully to client")
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
        listenForClientMessage()
    case .failed(let error):
        connectionDidFail(error: error)
    default:
        break
    }
}

func stop() {
    print("Connection with Client will stop")
}

private func connectionDidFail(error: Error) {
    print("Connection with Client did fail, error: \(error)")
    stop(error: error)
}

private func connectionDidEnd() {
    print("Connection with Client did end")
    stop(error: nil)
}

private func stop(error: Error?) {
    connection.stateUpdateHandler = nil
    connection.cancel()
    exit(EXIT_SUCCESS)
}


//
// ****************************************************************
// SocketClient
// main.swift created on 3/22/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

import Foundation
import Network

print("Starting Swift Socket Client using MTE Version \(MteBase.getVersion())")

// Set ipAddress
print("Type Server IP or hit [ENTER] for \(Settings.ipAddress)")
var ipAddress = readLine(strippingNewline: true)
if ipAddress == "" {
    ipAddress = Settings.ipAddress
}
print("Server is at \(ipAddress!)")

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

// IMPORTANT! ** This is an entirely insecure way of setting Entropy and MUST NOT be used in a "real"
// application. Please see MTE Developer Guide for more information.
// Create all-zero entropy for this lab.
let entropyBytes = MteBase.getDrbgsEntropyMinBytes(drbg)
var entropy = [UInt8](repeating: 0, count: entropyBytes)

var personalizationString: String = "demo"

// In this Lab, we set the encoder and decoder nonces differently so the encoded payloads will appear different
// even though the data prior to encoding is the same. They are reversed on the Client so they match up with
// the Server
var encoderNonce: UInt64 = 1
var decoderNonce: UInt64 = 0


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
    
    // Set our Runtime Options class varibles
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

print("MTE Setup SUCCESS. \n\nSetting up Client")

let nwHost = NWEndpoint.Host(ipAddress!)
let nwPort = NWEndpoint.Port(rawValue: port!)!
let nwConnection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
let queue = DispatchQueue(label: "Client connection Q")

print("Connection with Server will start")
nwConnection.stateUpdateHandler = stateDidChange(to:)
nwConnection.start(queue: queue)
var command: String?

func listenForUserInput() {
    print("\nType your message to send and hit [ENTER] OR\n\t 'quit' to end session...")
    command = readLine(strippingNewline: true)
    if command == "" {
        command = "Some default text"
    }
    if command!.lowercased() == "quit" {
        stop()
    }
    send(data: [UInt8](command!.utf8))
}

RunLoop.current.run()

func send(data: [UInt8]) {
    
    // Use MTE to encode the data
    let encodeResult = encoder.encode(data)
    if encodeResult.status != mte_status_success {
        print("MTE encode ERROR (\(MteBase.getStatusName(status))): " +
                MteBase.getStatusDescription(status))
        exit(EXIT_FAILURE)
    }
    
    // Send the length first
    let length = Int32(encodeResult.encoded.count)
    let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
    
    // Send the data length first . . .
    nwConnection.send(content: dataLength, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
        }
    }))
    
    // Then, send the encoded data
    nwConnection.send(content: encodeResult.encoded, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            return
        }
        print("\nEncoded data (as Ascii Hex only for display here): \n\t\(encodeResult.encoded.bytesToHex())")
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
            print("Response from Server (as Ascii Hex only for display here): \n\t\(data.bytes.bytesToHex())")
            
            
            let decodeResult = decoder.decode(data.bytes)
            if decodeResult.status != mte_status_success {
                print("MTE decode ERROR (\(MteBase.getStatusName(status))): " +
                        MteBase.getStatusDescription(status))
                exit(EXIT_FAILURE)
            }
            
            guard let message = String(bytes: decodeResult.decoded, encoding: .utf8) else {
                print("unable to retrieve text string from data")
                exit(EXIT_FAILURE)
            }
            print("Decoded response from Server: \n\t\(message)")
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
    print("Connection with Server will stop")
    stop(error: nil)
}

private func connectionDidFail(error: Error) {
    print("Connection with Server did fail, error: \(error)")
    stop(error: error)
}

private func connectionDidEnd() {
    print("Connection with Server did end")
    stop(error: nil)
}

private func stop(error: Error?) {
    nwConnection.stateUpdateHandler = nil
    nwConnection.cancel()
    exit(EXIT_SUCCESS)
}

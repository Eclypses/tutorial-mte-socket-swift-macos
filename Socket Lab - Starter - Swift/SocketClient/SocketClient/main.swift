//
// ****************************************************************
// SocketClient
// main.swift created on 3/22/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

import Foundation
import Network

print("Starting Swift Socket Client Starter")

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


// MARK: MTE Setup


print("MTE Setup SUCCESS (if MTE was being implemented :)). \n\nSetting up Client")

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
    
    
    // Send the length first
    let length = Int32(data.count)
    let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
    
    // Send the data length first . . .
    nwConnection.send(content: dataLength, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
        }
    }))
    
    // Then, send the encoded data
    nwConnection.send(content: data, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            return
        }
        print("\nEncoded data (as Ascii Hex only for display here): \n\t\(data.bytesToHex())")
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
            
            // Decode data with MTE
            
            guard let message = String(bytes: data, encoding: .utf8) else {
                print("unable to retrieve text string from data")
                exit(EXIT_FAILURE)
            }
            print("Response from Server: \n\t\(message)")
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

//
// ****************************************************************
// SocketClient
// main.swift created on 3/22/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

import Foundation
import Network

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
    // Send the length first
    let length = Int32(data.count)
    let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
    
    // Send the data length first . . .
    nwConnection.send(content: dataLength, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
        }
    }))
    
    // Then, send the data
    nwConnection.send(content: data, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            return
        }
        
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
            
            print("Received packet: \n\(String(describing: String(bytes: data, encoding: .utf8)))")
            
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

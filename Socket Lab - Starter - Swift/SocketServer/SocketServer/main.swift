//
// ****************************************************************
// SocketServer
// main.swift created on 3/22/21 by Greg Waggoner
// Copyright © 2021 Eclypses Inc. All rights reserved.
// ****************************************************************

import Foundation
import Network

print("Starting Swift Socket Server Starter")

let ipv4Addresses = getipv4Addresses()
print("Server will listen on \(ipv4Addresses[0])")

// Set port
print("Type Server port or hit [ENTER] for \(Settings.port)")
var portStr = readLine(strippingNewline: true)
let port = portStr != ""  ? UInt16(portStr!) : Settings.port
print("Server port is: \(port!)")

//MARK: MTE Properties


// MARK: MTE Setup

print("MTE Setup SUCCESS (if we had MTE implemented :)). \n\nSetting up Server")

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
            print("Message from client (as Ascii Hex only for display here): \n\t\(data.bytes.bytesToHex())")
            
            // This is where message from client would be decoded with MTE

            guard let message = String(bytes: data.bytes, encoding: .utf8) else {
                print("Unable to retrieve text string from data")
                return
            }
            print("Message from Client: \n\t\(message)")
            
            // Echo back to Client. Data would be re-encoded in send() function
            send(data: data.bytes)
        }
    }
}

func send(data: [UInt8]) {
    
    // This is where response to client would be encoded with MTE
    
    print("Response data (as Ascii Hex only for display here): \n\t\(data.bytesToHex())")
    
    // Send the data length first in big endian format
    let length = Int32(data.count)
    let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
    connection.send(content: dataLength, completion: .contentProcessed( { error in
        if let error = error {
            connectionDidFail(error: error)
            return
        }
    }))
    
    // Then send the data
    connection.send(content: data, completion: .contentProcessed( { error in
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


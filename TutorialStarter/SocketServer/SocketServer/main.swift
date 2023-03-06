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

let ipv4Addresses = getipv4Addresses()
print("Server will listen on \(ipv4Addresses[0])")

// Set port
print("Please enter port to use, press Enter to use default \(Settings.port):")
var portStr = readLine(strippingNewline: true)
let port = portStr != ""  ? UInt16(portStr!) : Settings.port

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
            print("Received packet: \n\(data)")
            
            // Echo back to Client
            send(data: [UInt8](data))
        }
    }
}

func send(data: [UInt8]) {
    
    
    print("Packet being sent: \n\(data)")
    
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


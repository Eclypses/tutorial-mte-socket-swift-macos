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

public class ClientSocketManager {
    
    weak var delegate:SocketManagerDelegate?
    private var connection: NWConnection!
    private var port: NWEndpoint.Port
    private var ipAddress: String
    
    public init(ipAddress: String, port: UInt16) {
        // MARK: Socket Setup
        
        // Initialize variables
        self.port = NWEndpoint.Port(rawValue: port)!
        self.ipAddress = ipAddress
    }
    
    public func start() throws {
        print("Client starting...")
        // Start Client
        let nwHost = NWEndpoint.Host(self.ipAddress)
        let nwPort = NWEndpoint.Port(rawValue: self.port.rawValue)!
        connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        let queue = DispatchQueue(label: "Client connection Q")
        
        connection.stateUpdateHandler = stateDidChange(to:)
        connection.start(queue: queue)
        
        RunLoop.current.run()
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            print("Client connected to Server.")
            self.delegate?.sendInfoToServer()
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }
    
    private func connectionDidFail(error: Error) {
        print("Connection with Client did fail, error: \(error)")
        stop(error: error)
    }
    
    private func connectionDidEnd() {
        print("Connection closed.")
        stop(error: nil)
    }
    
    func stop(error: Error?) {
        connection.stateUpdateHandler = nil
        connection.cancel()
        exit(EXIT_SUCCESS)
    }
    
    public func sendMessage(header:Character, message:[UInt8]) {
        // Get the length of the packet to send.
        let length = Int32(message.count);
        
        // Set the length to big-endian.
        let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
        
        // Send the message size as big-endian.
        connection.send(content: dataLength,  completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
        }))
        
        // Send the header byte.
        let headerString = String(header)
        let headerData = headerString.data(using: .utf8)
        connection.send(content: headerData,  completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
        }))
        
        // Send the actual message.
        connection.send(content: message,  completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
        }))
    }
    
    public func receiveMessage() {
        // Create recvMsg struct.
        var length: uint32 = 0
        
        // Get the message size coming in.
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, _, isComplete, error) in
            if isComplete {
                self.connectionDidEnd()
                return
            } else if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("Received no length prefix data")
                exit(EXIT_FAILURE)
            }
            
            // Retrieve the length of the incoming data in Big Endian format
            length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian}
            
            // Receive the header byte.
            self.connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { (data, _, isComplete, error) in
                guard let data = data, !data.isEmpty else {
                    print("Received no message data")
                    exit(EXIT_FAILURE)
                }
                let headerString = String(data: data, encoding: .utf8) ?? "\0"
                let header = Array(headerString)[0]
                
                self.connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { (data, _, isComplete, error) in
                    guard let data = data, !data.isEmpty else {
                        print("Received no message data")
                        exit(EXIT_FAILURE)
                    }
                    
                    // Let delgate handle message.
                    self.delegate?.didReceiveMessage(header: header, data: data.bytes)
                    
                }
            }
        }
        
    }
    
}

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

public class ServerSocketManager {
    
    weak var delegate:SocketManagerDelegate?
    private var connection: NWConnection!
    private var listener: NWListener!
    private var port: NWEndpoint.Port
    
    public init(port: UInt16) {
        // MARK: Socket Setup
        
        // Initialize variables
        self.port = NWEndpoint.Port(rawValue: port)!
        listener = try! NWListener(using: .tcp, on: self.port)
    }
    
    public func start() throws {
        print("Server starting...")
        // Start Server
        listener.stateUpdateHandler = listenerStateDidChange(to:)
        listener.newConnectionHandler = listenerDidAcceptConnection(nwConnection:)
        listener.start(queue: .main)
        RunLoop.current.run()
    }
    
    private func listenerDidAcceptConnection(nwConnection: NWConnection) {
        connection = nwConnection
        connection.stateUpdateHandler = connectionStateDidChange(to:)
        connection.start(queue: .main)
        listener.cancel()
    }
    
    private func listenerStateDidChange(to newState: NWListener.State) {
        switch newState {
        case .ready:
            print("Listening for new Client connection . . .\n")
        case .failed(let error):
            print("Listener failure, error: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        case .waiting(let error):
            connectionDidFail(error: error)
        default:
            break
        }
    }
    
    private func connectionStateDidChange(to state: NWConnection.State) {
        switch state {
        case .waiting(let error):
            connectionDidFail(error: error)
        case .ready:
            let ipv4Addresses = getipv4Addresses()
            print("Server will listen on \(ipv4Addresses[0])")
            print("Connected with Client")
            print("\nListening for messages from Client . . .\n")
            
            receiveMessage()
        case .failed(let error):
            connectionDidFail(error: error)
        default:
            break
        }
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
    
    public func sendMessage(header:Character, message:[UInt8]) {
        // Get the length of the packet to send.
        let length = Int32(message.count);
        
        // Set the length to big-endian.
        let dataLength = withUnsafeBytes(of: length.bigEndian, Array.init)
        
        // Send the message size as big-endian.
        connection.send(content: dataLength,  completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
        }))
        
        // Send the header byte.
        let headerString = String(header)
        let headerData = headerString.data(using: .utf8)
        connection.send(content: headerData,  completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
        }))
        
        // Send the actual message.
        connection.send(content: message,  completion: .contentProcessed( { error in
            if let error = error {
                self.connectionDidFail(error: error)
                return
            }
        }))
    }
    
    public func receiveMessage() {
        // Create recvMsg struct.
        var length: uint32 = 0
        
        // Get the message size coming in.
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { (data, _, isComplete, error) in
            if isComplete {
                self.connectionDidEnd()
                return
            } else if let error = error {
                self.connectionDidFail(error: error)
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("Received no length prefix data")
                exit(EXIT_FAILURE)
            }
            
            // Retrieve the length of the incoming data in Big Endian format
            length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian}
            
            // Receive the header byte.
            self.connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { (data, _, isComplete, error) in
                guard let data = data, !data.isEmpty else {
                    print("Received no message data")
                    exit(EXIT_FAILURE)
                }
                let headerString = String(data: data, encoding: .utf8) ?? "\0"
                let header = Array(headerString)[0]
                
                self.connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { (data, _, isComplete, error) in
                    guard let data = data, !data.isEmpty else {
                        print("Received no message data")
                        exit(EXIT_FAILURE)
                    }
                    
                    // Let delgate handle message.
                    self.delegate?.didReceiveMessage(header: header, data: data.bytes)
                    
                }
            }
        }
        
    }
    
}


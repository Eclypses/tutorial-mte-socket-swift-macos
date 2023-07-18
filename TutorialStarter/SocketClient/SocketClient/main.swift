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

}



protocol SocketManagerDelegate: AnyObject {

    func didReceiveMessage(header:Character, data:[uint8])

    func sendUserInputToServer()

}



// The states the manager can be in.

public enum state {

    case ready

    case mainLoop

    case error

}



// ======================================

// Step 1 - Encoder and Decoder Creation

// Step 2 - Licensing

// Step 4 - Instantiation

// Implemented with ClientMteHelper.swift

// ======================================



class Main:SocketManagerDelegate {

    var mteInfo = [String:[uint8]]()

    var socketManager:ClientSocketManager!

    var input:String = ""

    

    // Set state to initial ready state.

    var managerState: state = state.ready

    

    init(ipAddress: String, port: UInt16) {

        socketManager = ClientSocketManager(ipAddress: ipAddress, port: port)

        socketManager.delegate = self

        do {

            

            managerState = state.mainLoop

            

            try socketManager.start()

        } catch {

            print (error)

            exit(EXIT_FAILURE)

        }

        

        // End the program.

        closeProgram()

    }

    

    // =============================

    // Step 3 - Information Exchange

    // =============================

    

    func sendMessage(message:[uint8]) -> Bool {

        // =================

        // Step 5 - Encoding

        // =================

        

        // Send the message.

        socketManager.sendMessage(header: "m", message: message)

        

        return true

    }

    

    func didReceiveMessage(header: Character, data: [uint8]) {

        // Determine what to do with message based on current manager state.

        switch (managerState) {

        case state.mainLoop:

            receiveFromServer(header: header, data: data)

            break

        default:

            break

        }

        

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

        // =================

        // Step 6 - Decoding

        // =================

        

        // Compare the received message to the original.

        if input == String(bytes: data, encoding: .utf8) {

            print("The original input and decoded return match.\n")

        } else {

            print("The original input and decoded return DO NOT match.\n")

            exit(EXIT_FAILURE)

        }

        

        // Get the next input.

        sendUserInputToServer()

    }

    

    func closeProgram() {

        // =================

        // Step 7 - Clean Up

        // =================

        print("Program stopped.")

        socketManager.stop(error: nil)

    }

}


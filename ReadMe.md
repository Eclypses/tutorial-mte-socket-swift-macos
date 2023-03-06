![Eclypses Logo alt text](./Eclypses_H_C_M-R.png =500x)

<div align="center" style="font-size:40pt; font-weight:900; font-family:arial; margin-top:300px; " >
Swift MacOS Server and Client Socket Tutorials</div>

<div align="center" style="font-size:28pt; font-family:arial; " >
MTE Implementation Tutorials </div>
<div align="center" style="font-size:15pt; font-family:arial; " >
Using MTE version 2.2.x</div>

[Introduction](#introduction)

[Socket Tutorial Server and Client](#socket-tutorial-server-and-client)<br>
- [Add MTE Files](#add-mte-files)<br>
- [Create Initial values](#create-initial-values)<br>
- [Check For License](#check-for-license)<br>
- [Create Encoder and/or Decoder](#create-encoder-and/or-decoder)<br>
- [Encode and Decode Sample Calls](#encode-and-decode-sample-calls)<br>

[Contact Eclypses](#contact-eclypses)


<div style="page-break-after: always; break-after: page;"></div>

# Introduction

This tutorial is sending messages via a socket connection. This is only a sample, the MTE does NOT require the usage of sockets, you can use whatever communication protocol that is needed.

This tutorial demonstrates how to use Mte Core, Mte MKE and Mte Fixed Length. Depending on what your needs are, these three different implementations can be used in the same application OR you can use any one of them. They are not dependent on each other and can run simultaneously in the same application if needed. 

The SDK that you received from Eclypses may not include the MKE or MTE FLEN add-ons. If your SDK contains either the MKE or the Fixed Length add-ons, the name of the SDK will contain "-MKE" or "-FLEN". If these add-ons are not there and you need them please work with your sales associate. If there is no need, please just ignore the MKE and FLEN options.

Here is a short explanation of when to use each, but it is encouraged to either speak to a sales associate or read the dev guide if you have additional concerns or questions.

***MTE Core:*** This is the recommended version of the MTE to use. Unless payloads are large or sequencing is needed this is the recommended version of the MTE and the most secure.

***MTE MKE:*** This version of the MTE is recommended when payloads are very large, the MTE Core would, depending on the token byte size, be multiple times larger than the original payload. Because this uses the MTE technology on encryption keys and encrypts the payload, the payload is only enlarged minimally.

***MTE Fixed Length:*** This version of the MTE is very secure and is used when the resulting payload is desired to be the same size for every transmission. The Fixed Length add-on is mainly used when using the sequencing verifier with MTE. In order to skip dropped packets or handle asynchronous packets the sequencing verifier requires that all packets be a predictable size. If you do not wish to handle this with your application then the Fixed Length add-on is a great choice. This is ONLY an encoder change - the decoder that is used is the MTE Core decoder.

In this tutorial we are creating an MTE Encoder and an MTE Decoder in the server as well as the client because we are sending secured messages in both directions. This is only needed when there are secured messages being sent from both sides, the server as well as the client. If only one side of your application is sending secured messages, then the side that sends the secured messages should have an Encoder and the side receiving the messages needs only a Decoder.

These steps should be followed on the server side as well as on the client side of the program.

**IMPORTANT**
>Please note the solution provided in this tutorial does NOT include the MTE library or supporting MTE library files. If you have NOT been provided an MTE library and supporting files, please contact Eclypses Inc. The solution will only work AFTER the MTE library and MTE library files have been incorporated.


# Socket Tutorial Server and Client

<ol>
<li>At the root of the project, create a new directory named "MTE", this will hold the needed MTE files.</li>
<br>
<li>Copy the "include" and "lib" directories from the mte-Darwin package into the new "MTE" directory.</li>
<br>
<li>If using the MTE Core, copy the MteBase.swift, MteEnc.swift, and MteDec.swift files from the "src/swift" directory from the package to the "MTE" directory. If using the MTE MKE, copy the MteBase.swift, MteMkeEnc.swift, and MteMkeDec.swift files. If using the Mte Fixed length, copy the MteBase.swift, MteFlenEnc.swift, and MteDec.swift files.</li>
<br>
<li>Update the project settings of both SocketClient and SocketServer in Xcode with the following:</li>
<ul>
<li>Update the "Header Search Paths" in the "Build Settings" tab to include the "Mte/include" directory.</li>
<li>Update the "Library Search Paths" in the "Build Settings" tab to include the "Mte/lib" directory.</li>
<li>Add the swift source files in the "Compile Sources" section in the "Build Phases" tab of the SocketClient/SocketServer target.</li>
<li>Add the libmte_mteb.a,libmte_mtesupp.a, libmte_mtee.a, and libmte_mted.a files from the "MTE/lib" directory to the "Link Binary With Libraries" section in the "Build Phases" tab of the SocketClient/SocketServer target. If using the MTE MKE, also add the libmte_mkee.a and libmte_mked.a files. If using MTE Fixed length, also add the libmte_flen.a file.</li>
</ul>
<br>
<li>Navigate to the "Bridging-Header.h" file for both the SocketClient and SocketServer projects. Ensure that the core encoder and decoder include statements are uncommented.

```objective-c
// Core decoder (MteDec).
#include "mte_dec.h"

// Core encoder (MteEnc).
#include "mte_enc.h"
```

If using the MTE MKE, uncomment the include statements for the MKE add-on.
```objective-c
// Managed-Key Encryption Add-On decoder (MteMkeDec).
#include "mte_mke_dec.h"

// Managed-Key Encryption Add-On encoder (MteMkeEnc).
#include "mte_mke_enc.h"
```
If using the MTE Fixed length, uncomment the include statement for the FLEN add-on.
```objective-c
// Fixed-Length Add-On encoder (MteFlenEnc).
#include "mte_flen_enc.h"
```

</li>
<li>Navigate to each "main.swift" file for both the SocketClient and SocketServer projects. Create the MTE Decoder and MTE Encoder as well as the accompanying MTE<sup>TM</sup> status for each as global variables. Also include fixed length parameter if using FLEN.</li>

```swift
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
```

<li>We need to be able to set the entropy, nonce, and personalization/identification values.</li>
These values should be treated like encryption keys and never exposed. For demonstration purposes in the tutorial we are setting these values in the code. In a production environment these values should be protected and not available to outside sources. For the entropy, we have to determine the size of the allowed entropy value based on the drbg we have selected. A code sample below is included to demonstrate how to get these values.

```swift
let entropyBytes = MteBase.getDrbgsEntropyMinBytes(encoder.getDrbg())
```

To set the entropy in the tutorial we are simply getting the minimum bytes required and creating a byte array of that length that contains all zeros. We want to set the default first to be blank.

```swift
// Create 'all-zero' entropy for this tutorial.
let entropyBytes = MteBase.getDrbgsEntropyMinBytes(encoder.getDrbg())
encoderEntropy = [UInt8](repeating: Character("0").asciiValue!, count: entropyBytes)

```
To set the nonce and the personalization/identifier string we are simply adding our default values as global variables to the top of the class.
```swift
// OPTIONAL!!! adding 1 to decoder nonce so return value changes -- same nonce can be used for encoder and decoder
// on client side values will be switched so they match up encoder to decoder and vice versa
var encoderNonce: UInt64 = 0
var decoderNonce: UInt64 = 1
var personalizationString: String = "demo"

```

<li>To ensure the MTE library is licensed correctly, run the license check. The LicenseCompanyName, and LicenseKey below should be replaced with your company’s MTE license information provided by Eclypses. If a trial version of the MTE is being used any value can be passed into those fields and it will work.</li>

```swift
// Check mte license
if !MteBase.initLicense("LicenseCompanyName", "LicenseKey") {
    print("License init error (\(MteBase.getStatusName(mte_status_license_error))): " +
          MteBase.getStatusDescription(mte_status_license_error))
    exit(Int32(mte_status_license_error.rawValue))
}
```

<li>Create MTE Decoder Instances and MTE Encoder Instances.</li>
Here is a sample that creates the MTE Encoder.

```swift
// Initialize Encoder

// IMPORTANT! ** This is an entirely insecure way of setting Entropy and MUST NEVER be used in a "real"
// application. Please see MTE Developer's Guide for more information.
// Create 'all-zero' entropy for this tutorial.
let entropyBytes = MteBase.getDrbgsEntropyMinBytes(encoder.getDrbg())
encoderEntropy = [UInt8](repeating: Character("0").asciiValue!, count: entropyBytes)

encoder.setEntropy(&encoderEntropy)
encoder.setNonce(encoderNonce)
encoderStatus = encoder.instantiate([UInt8](personalizationString.utf8))
if encoderStatus != mte_status_success {
    print("Encoder Instantiate error (\(MteBase.getStatusName(encoderStatus))): " +
          MteBase.getStatusDescription(encoderStatus))
    exit(EXIT_FAILURE)
}
```
*(For further information on Encoder constructor and initialization review the DevelopersGuide)*
Here is a sample that creates the MTE Decoder.
```swift
// Initialize Decoder

// When entropy is set in the encoder, it is 'zeroed' out, therefore, we need to 'refill' it before setting in decoder
// IMPORTANT! ** As stated above, this is an entirely insecure way of setting the entropy
// parameter and MUST NEVER be used in a real application.
decoderEntropy = [UInt8](repeating: Character("0").asciiValue!, count: entropyBytes)

decoder.setEntropy(&decoderEntropy)
decoder.setNonce(decoderNonce)
decoderStatus = decoder.instantiate([UInt8](personalizationString.utf8))
if decoderStatus != mte_status_success {
    print("Decoder Instantiate error (\(MteBase.getStatusName(decoderStatus))): " +
          MteBase.getStatusDescription(decoderStatus))
    exit(EXIT_FAILURE)
}
```
*(For further information on Decoder constructor and initialization review the DevelopersGuide)*
<br>
***When the above steps are completed on both the server and the client, the MTE will be ready for use.***

<li>Finally, we need to add the MTE calls to encode and decode the messages that we are sending and receiving from the other side. (Ensure on the server side the Encoder is used to encode the outgoing text, then the Decoder is used to decode the incoming response.)</li>
<br>
Here is a sample of how to do this on the Client side.

```swift
// Use MTE to encode the data
let encodedReturn = encoder.encode(data)
if encodedReturn.status != mte_status_success {
	print("Error encoding: Status (\(MteBase.getStatusName(encodedReturn.status)))/ " +
		MteBase.getStatusDescription(encodedReturn.status))
	exit(EXIT_FAILURE)
}

// Decode the incoming data.
let returnedText = decoder.decode(data.bytes)
if returnedText.status != mte_status_success {
	print("Error decoding: Status (\(MteBase.getStatusName(returnedText.status)))/" +
		MteBase.getStatusDescription(returnedText.status))
	exit(EXIT_FAILURE)
}
```
Here is a sample of how to do this on the Server side.
```swift
// Decode the incoming data.
let decodeResult = decoder.decode(data.bytes)
if decodeResult.status != mte_status_success {
	print("Error decoding: Status: (\(MteBase.getStatusName(decodeResult.status)))/ " +
		MteBase.getStatusDescription(decodeResult.status))
	exit(EXIT_FAILURE)
)

// Encode the data with MTE
let encodedReturn = encoder.encode(data)
if encodedReturn.status != mte_status_success {
	print("Error encoding: Status: (\(MteBase.getStatusName(encodedReturn.status)))/ " +
		MteBase.getStatusDescription(encodedReturn.status))
	exit(EXIT_FAILURE)
}
```
</ol>
<div style="page-break-after: always; break-after: page;"></div>

# Contact Eclypses

<p align="center" style="font-weight: bold; font-size: 22pt;">For more information, please contact:</p>
<p align="center" style="font-weight: bold; font-size: 22pt;"><a href="mailto:info@eclypses.com">info@eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 22pt;"><a href="https://www.eclypses.com">www.eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 22pt;">+1.719.323.6680</p>

<p style="font-size: 8pt; margin-bottom: 0; margin: 300px 24px 30px 24px; " >
<b>All trademarks of Eclypses Inc.</b> may not be used without Eclypses Inc.'s prior written consent. No license for any use thereof has been granted without express written consent. Any unauthorized use thereof may violate copyright laws, trademark laws, privacy and publicity laws and communications regulations and statutes. The names, images and likeness of the Eclypses logo, along with all representations thereof, are valuable intellectual property assets of Eclypses, Inc. Accordingly, no party or parties, without the prior written consent of Eclypses, Inc., (which may be withheld in Eclypses' sole discretion), use or permit the use of any of the Eclypses trademarked names or logos of Eclypses, Inc. for any purpose other than as part of the address for the Premises, or use or permit the use of, for any purpose whatsoever, any image or rendering of, or any design based on, the exterior appearance or profile of the Eclypses trademarks and or logo(s).
</p>

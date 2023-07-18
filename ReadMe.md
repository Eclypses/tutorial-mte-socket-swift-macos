

<img src="Eclypses.png" style="width:50%;margin-right:0;"/>

<div align="center" style="font-size:40pt; font-weight:900; font-family:arial; margin-top:300px; " >
Swift MacOS Socket Tutorial</div>
<br>
<div align="center" style="font-size:28pt; font-family:arial; " >
MTE Implementation Tutorial (MTE Core, MKE, MTE Fixed Length)</div>
<br>
<div align="center" style="font-size:15pt; font-family:arial; " >
Using MTE version 3.1.x</div>





[Introduction](#introduction)

[Socket Tutorial Server and Client](#socket-tutorial-server-and-client)


<div style="page-break-after: always; break-after: page;"></div>

# Introduction

This tutorial is sending messages via a socket connection. This is only a sample, the MTE does NOT require the usage of sockets, you can use whatever communication protocol that is needed.

This tutorial demonstrates how to use Mte Core, Mte MKE and Mte Fixed Length. For this application, only one type can be used at a time; however, it is possible to implement any and all at the same time depending on needs.

This tutorial contains two main programs, a client and a server. Note that any of the available languages can be used for any available platform as long as communication is possible. It is just recommended that a server program is started first and then a client program can be started.

The MTE Encoder and Decoder need several pieces of information to be the same in order to function properly. This includes entropy, nonce, and personalization. If this information must be shared, the entropy MUST be passed securely. One way to do this is with a Diffie-Hellman approach. Each side will then be able to create two shared secrets to use as entropy for each pair of Encoder/Decoder. The two personalization values will be created by the client and shared to the other side. The two nonce values will be created by the server and shared.

The SDK that you received from Eclypses may not include the MKE or MTE FLEN add-ons. If your SDK contains either the MKE or the Fixed Length add-ons, the name of the SDK will contain "-MKE" or "-FLEN". If these add-ons are not there and you need them please work with your sales associate. If there is no need, please just ignore the MKE and FLEN options.

Here is a short explanation of when to use each, but it is encouraged to either speak to a sales associate or read the dev guide if you have additional concerns or questions.

***MTE Core:*** This is the recommended version of the MTE to use. Unless payloads are large or sequencing is needed this is the recommended version of the MTE and the most secure.

***MTE MKE:*** This version of the MTE is recommended when payloads are very large, the MTE Core would, depending on the token byte size, be multiple times larger than the original payload. Because this uses the MTE technology on encryption keys and encrypts the payload, the payload is only enlarged minimally.

***MTE Fixed Length:*** This version of the MTE is very secure and is used when the resulting payload is desired to be the same size for every transmission. The Fixed Length add-on is mainly used when using the sequencing verifier with MTE. In order to skip dropped packets or handle asynchronous packets the sequencing verifier requires that all packets be a predictable size. If you do not wish to handle this with your application then the Fixed Length add-on is a great choice. This is ONLY an encoder change - the decoder that is used is the MTE Core decoder.

***IMPORTANT NOTE***
>If using the fixed length MTE (FLEN), all messages that are sent that are longer than the set fixed length will be trimmed by the MTE. The other side of the MTE will NOT contain the trimmed portion. Also messages that are shorter than the fixed length will be padded by the MTE so each message that is sent will ALWAYS be the same length. When shorter message are "decoded" on the other side the MTE takes off the extra padding when using strings and hands back the original shorter message, BUT if you use the raw interface the padding will be present as all zeros. Please see official MTE Documentation for more information.

In this tutorial, there is an MTE Encoder on the client that is paired with an MTE Decoder on the server. Likewise, there is an MTE Encoder on the server that is paired with an MTE Decoder on the client. Secured messages wil be sent to and from both sides. If a system only needs to secure messages one way, only one pair could be used.

**IMPORTANT**
>Please note the solution provided in this tutorial does NOT include the MTE library or supporting MTE library files. If you have NOT been provided an MTE library and supporting files, please contact Eclypses Inc. The solution will only work AFTER the MTE library and MTE library files have been incorporated.
  

# Socket Tutorial Server and Client

## MTE Directory and File Setup
<ol>
<li>
Navigate to the "tutorial-mte-socket-swift-macos/TutorialMTE" directory.
</li>
<li>
Create a directory named "MTE". This will contain all needed MTE files.
</li>
<li>
Copy the "lib" directory and contents from the MTE SDK into the "MTE" directory.
</li>
<li>
Copy the "include" directory and contents from the MTE SDK into the "MTE" directory.
</li>
<li>
Copy the "src/swift" directory and contents from the MTE SDK into the "MTE" directory.
</li>
</ol>


The common source code between the client and server will be found in the "common" directory. The client and server specific source code will be found in their respective directories.

## Project Settings
<ol>
<li>
Ensure that the header search path contains the path to the "../MTE/include" and "../ecdh/include" directories. 
</li>
<li>
Ensure that the library search path contains the path to the "../MTE/lib" and "../ecdh/lib" directories.
</li>
<li>
The project will require either the dynamic MTE library or the static libraries depending on add-ons; for MTE Core: mte_mtee, mte_mted, and mte_mteb in that order; for MKE add-on: mte_mkee, mte_mked, mte_mtee, mte_mted, and mte_mteb in that order; or for Fixed length add-on: mte_flen, mte_mtee, mte_mted, and mte_mteb in that order.
</li>
</ol>

## MTE Setup and Usage

The following steps are important to ensure a secure and effective way to set up the MTE and its use. The important points will be highlighted within the source code.
<ol>
<li>
Encoder and Decoder Creation - Create Encoder and Decoder objects that will be used throughout the program. Select the core MTE, or if available, an add-on type (such as MKE or fixed-length) can be chosen. These must match between the client and server, i.e., MKE must be used for both the client and server (note that fixed-length is only an Encoder add-on, the matching Decoder will still use the core). If there are runtime options available, those can be selected, or the default options can be used.
</li>
<br>
<li>
Licensing - Ensure the MTE is licensed correctly. Most libraries will need to be given a valid company name and license key in order for the MTE to encode or decode properly. It is highly important that these be kept confidential.
</li>
<br>
<li>
Information Exchange - To achieve the best possible security, the best practice is to create a way for the two sides to have a shared secret to use for entropy for the MTE. In these tutorials, an Elliptic Curve Diffie-Hellman (ECDH) key agreement protocol is utilized to create keys. The client and server create their own private and public keys, and then exchange public keys. Each side has one Encoder and one Decoder (client Encoder matched to server Decoder, and server Encoder matched to client Decoder), thus each side will share two public keys. The public key received from the other side will be referred to as the peer public key. These tutorials will also have the client create two personalization strings and the server create two nonces, and these will be exchanged as well. For the Starter project, all packets will be sent with the following protocol: the payload size as a 32 bit number in big endian, followed by the actual payload. The MTE project adds a header byte before the payload. Each of these exchanges needed for MTE setup use a header byte ("1","2","3","4") in the communication packet to signify the specific information being sent and received.
</li>
<br>
<li>
instantiation - To utilize the MTE in a secure fashion, the shared secret will be created at the last possible point in the code and cleared out as soon as possible. The shared secret is produced using the private key (never exchanged) and the peer public key obtained from the other side. This shared secret is fed directly to the method that sets entropy for the Encoder or Decoder being constructed. The nonce is set, and then the personalization string is used for instantiation. If all necessary information has been exchanged and set properly, the matching Encoders and Decoders will now be synchronized.
</li>
<br>
<li>
Encoding - When sending a message intended to be securely encoded by the MTE, the encode method is called with the Encoder and that encoded result is being sent. In this tutorial, the MTE project adds a header byte "m" after the payload size to signify that it is a message encoded by the MTE. 
</li>
<br>
<li>
Decoding - When an encoded message is received, it is decoded by the Decoder and the result is passed along to the program as normal. In this tutorial, the MTE project will expect a packet with the header byte "m" to signify that it was a message encoded by the MTE.
</li>
<br>
<li>
Clean Up - After the program has finished, cleanup is implemented by using the uninstatiate methods for the Encoders and Decoders.
</li>
</ol>

<div style="page-break-after: always; break-after: page;"></div>

# Contact Eclypses

<p align="center" style="font-weight: bold; font-size: 20pt;">Email: <a href="mailto:info@eclypses.com">info@eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 20pt;">Web: <a href="https://www.eclypses.com">www.eclypses.com</a></p>
<p align="center" style="font-weight: bold; font-size: 20pt;">Chat with us: <a href="https://developers.eclypses.com/dashboard">Developer Portal</a></p>
<p style="font-size: 8pt; margin-bottom: 0; margin: 100px 24px 30px 24px; " >
<b>All trademarks of Eclypses Inc.</b> may not be used without Eclypses Inc.'s prior written consent. No license for any use thereof has been granted without express written consent. Any unauthorized use thereof may violate copyright laws, trademark laws, privacy and publicity laws and communications regulations and statutes. The names, images and likeness of the Eclypses logo, along with all representations thereof, are valuable intellectual property assets of Eclypses, Inc. Accordingly, no party or parties, without the prior written consent of Eclypses, Inc., (which may be withheld in Eclypses' sole discretion), use or permit the use of any of the Eclypses trademarked names or logos of Eclypses, Inc. for any purpose other than as part of the address for the Premises, or use or permit the use of, for any purpose whatsoever, any image or rendering of, or any design based on, the exterior appearance or profile of the Eclypses trademarks and or logo(s).
</p>
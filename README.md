# Pwnagotchi

<p align="center">
    <a href="https://github.com/Sniffleupagus/pwnagotchi-snflpgs/releases/latest"><img alt="Release" src="https://img.shields.io/github/release/evilsocket/pwnagotchi.svg?style=flat-square"></a>
    <a href="https://github.com/Sniffleupagus/pwnagotchi-snflpgs/blob/master/LICENSE.md"><img alt="Software License" src="https://img.shields.io/badge/license-GPL3-brightgreen.svg?style=flat-square"></a>
    <a href="https://github.com/Sniffleupagus/pwnagotchi-snflpgs/graphs/contributors"><img alt="Contributors" src="https://img.shields.io/github/contributors/evilsocket/pwnagotchi"/></a>
</p>

[Pwnagotchi](https://pwnagotchi.ai/) is an [A2C](https://hackernoon.com/intuitive-rl-intro-to-advantage-actor-critic-a2c-4ff545978752)-based "AI" leveraging [bettercap](https://www.bettercap.org/) that learns from its surrounding WiFi environment to maximize the crackable WPA key material it captures (either passively, or by performing authentication and association attacks). This material is collected as PCAP files containing any form of handshake supported by [hashcat](https://hashcat.net/hashcat/), including [PMKIDs](https://www.evilsocket.net/2019/02/13/Pwning-WiFi-networks-with-bettercap-and-the-PMKID-client-less-attack/), 
full and half WPA handshakes.

![ui](https://i.imgur.com/X68GXrn.png)

... and so forth.  But about this fork:

## This fork has a multistage build process and parallel builds for different SBCs.
Currrently supported:
- Raspberry Pi Zero W (32-bit)
- Raspberry Pi Zero 2W, 3b+, 4, 5 (64-bit)
- Orange Pi Zero 2W (requires USB wifi dongle that has monitor mode support) (64-bit)
- Bananapi M2 Zero (kinda, maybe) (32-bit)
- Bananapi M4 Zero (64-bit)
  
The build process creates a base image for raspberry pis, to update system packages and build dependencies, then build the pwnagotchi image using that as a starting point. It saves a lot of time when updating pwnagotchi images, since the dependencies do not change as often.

## Make Targets
- base32 - 32-bit Raspberry Pi base image. Need to make this before making the pwnagotchi 32 bit image
- base64 - 64-bit Raspberry Pi base image. Need to make this before making the pwnagotchi 64 bit image
- image - 32-bit Raspberry pi pwnagotchi
- image64 - 64-bit Raspberry pi pwnagotchi
- orangepwn02w - orange pi zero 2w 64-bit pwnagotchi
- bananapwnm2zero - bananapi m2zero pwnagotchi (untested)
- bananapwnm4zero - bananapi m4zero pwnagotchi
- images - build both raspberry pi pwnagotchi images
- bases - build both raspberyr pi base images
- 4images - build both raspberry pi, orangepi02w and bananapim2zero

## Build for Raspberry Pi Zero W
Raspberry Pi Zero W is one of the better SBCs to run pwnagotchi. Its onboard Wifi is well supported by the nexmon driver. Packet injection works, and it does not "go blind" as often as the Pizero 2W seems to, as long as you throttle deauths. Pizero W has a 32-bit CPU. Torch wheels are not supplied by python repositories. I have build torch and torchvision wheels for armv6l and they are downloaded as part of this build. Building torch for the arm processor is done in a Qemu environment and takes hours on a decent iMac, so it is separate from this build (https://github.com/Sniffleupagus/Torch4Pizero). Compilations in this build under armv6l emulation take kind of a while. The whole pwnagotchi build takes almost 2 hours in VM on the iMac.

Clone this Repository. Then run "make base32". It will take a while.  Then "make image". Also takes a while.

## Build for 64-bit Raspberry Pi
These are easier.  Torch wheels exist, so they get downloaded from standard places. Build a base image, then final:
    make base64
    make image64

## Other SBCs
Orangepi and bananapim4zero builds use the images supplied by Orangepi or Bananapi on the SBC wiki pages. I will try to figure out which ones I used. Download the image, place it in build/images/ and rename as in the pwnagotchi.json.pkr.hcl file "source" section.  Then "make orangepwn02w" or "make bananapwnm4zero"

Bananapim2zero does have a chip with a nexmon driver. It does not currently have a torch wheel available, so no AI on this platform yet. Also untested build result. "make bananapwnm2zero"



## License

`pwnagotchi` is made with ♥  by [@evilsocket](https://twitter.com/evilsocket) and the [amazing dev team](https://github.com/evilsocket/pwnagotchi/graphs/contributors). It is released under the GPL3 license.

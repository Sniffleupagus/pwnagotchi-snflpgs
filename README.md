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



## License

`pwnagotchi` is made with ♥  by [@evilsocket](https://twitter.com/evilsocket) and the [amazing dev team](https://github.com/evilsocket/pwnagotchi/graphs/contributors). It is released under the GPL3 license.

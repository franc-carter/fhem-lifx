fhem-lifx
=========

An fhem driver for the LIFX Light Bulbs, you will need https://github.com/franc-carter/perl-lifx

The driver is split in two pieces, a Bridge that does the network communication between fhem and the Bulbs and a Bulb which represents the device specific information.

Put the following in your fhem config file to use it

    Define BRIDGE_NAME LIFXBridge

    define DEVICE_NAME LIFXBulb Label|XX:XX:XX:XX:XX:XX
    attr DEVICE_NAME setList off on

where DEVICE_NAME is the name you wish to call the device and XX:XX:XX:XX:XX:XX is the MAC address of the device and Label is the label/name if you have assigned on to Bulb


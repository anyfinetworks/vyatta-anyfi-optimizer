Vyatta CLI for ANYFI OPTIMIZER
==============================

# Goals and Objectives

Provide a Vyatta (and EdgeOS) CLI for Anyfi Optimizer, allowing for large scale
centralized break-out of Internet-bound SDWN data plane traffic. 

# Functional Specification

For more information see the
[ANYFI OPTIMIZER datasheet](http://www.anyfinetworks.com/files/anyfi-optimizer-datasheet.pdf).

# Configuration Commands

    service
      anyfi
        optimizer <txt: NAME>
          controller <ipv4: CONTROLLER ADDRESS>
          bridge <txt: BRIDGE NAME>
          rsa-key-pair file <txt: PATH OF PEM FILE>
          port-range <txt: UDP PORT RANGE TO USE FOR THIS SERVICE>
          authorization
            radius-server <ipv4: RADIUS SERVER ADDRESS>
              port <u16: RADIUS SERVER PORT>
              secret <txt: RADIUS SERVER SECRET>
          accounting
            radius-server <ipv4: RADIUS SERVER ADDRESS>
              port <u16: RADIUS SERVER PORT>
              secret <txt: RADIUS SERVER SECRET>
          nas
            identifier <txt: NAS IDENTIFIER>
            ip-address <txt: NAS IP ADDRESS>
            port <u16: NAS UDP PORT>

# Operational Commands

    show anyfi optimizer license  # Show license information.
    show anyfi optimizer <NAME>   # Show information about an optimizer instance.


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
          port-range <txt: UDP PORT RANGE TO USE FOR THIS SERVICE>
          break-out
            public-key <txt: BASE64 ENCODED RSA PUBLIC KEY>
            private-key <txt: BASE64 ENCODED RSA PRIVATE KEY>
            subnet <ip4net: SUBNET TO USE FOR IP NAT OF CLIENT TRAFFIC>
            ports-per-service <u16: NUMBER OF TCP/UDP NAT PORTS PER SERVICE>

# Operational Commands

    show anyfi optimizer license  # Show license information.
    show anyfi optimizer <NAME>   # Show information about an optimizer instance.


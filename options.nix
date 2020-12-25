{ config }:

import (./. + "/options/${config.networking.hostName}.${config.networking.domain}.nix")

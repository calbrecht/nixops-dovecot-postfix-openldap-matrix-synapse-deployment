{ config, lib, pkgs, ... }:
let
  fqdn = config.networking.hostName;
  opt = import (./. + "/options/${fqdn}.nix") { fqdn = fqdn; };
in {
  services.nginx.enable = true;
  
  services.nginx.virtualHosts."${fqdn}" = {
    serverAliases = opt.acme.aliases;
    enableACME = true;
  };

  security.acme = {
    preliminarySelfsigned = opt.acme.preliminarySelfsigned;
    production = opt.acme.production;
    certs."${fqdn}".allowKeysForGroup = true;
  };
}

{ config, lib, pkgs, ... }:
let
  fqdn = config.networking.hostName;
  opt = import (./. + "/options/${fqdn}.nix") { fqdn = fqdn; };
in {
  services.nginx.enable = true;
  
  services.nginx.commonHttpConfig = ''
    server_names_hash_bucket_size 64;
  '';

  services.nginx.virtualHosts."${fqdn}" = {
    serverAliases = opt.acme.aliases;
    enableACME = true;
  };

  security.acme = {
    preliminarySelfsigned = opt.acme.preliminarySelfsigned;
    production = opt.acme.production;
    certs."${fqdn}".allowKeysForGroup = true;
  };

  systemd.services."acme-${fqdn}".enable = opt.acme.production;
}

{ config, lib, pkgs, ... }:
let
  opt = import ./options.nix { inherit config; };
  fqdn = opt.fqdn;
in
{
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

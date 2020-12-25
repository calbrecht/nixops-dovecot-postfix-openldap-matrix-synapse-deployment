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
    acceptTerms = true;
    email = "admin@ngse.de";
    preliminarySelfsigned = opt.acme.preliminarySelfsigned;
    #deprecation detected 2020-12-24 certs."${fqdn}".allowKeysForGroup = true;
  } // lib.optionalAttrs (!opt.acme.production) {
    server = https://acme-staging-v02.api.letsencrypt.org/directory;
  };

  systemd.services."acme-${fqdn}".enable = true; #opt.acme.production;
}

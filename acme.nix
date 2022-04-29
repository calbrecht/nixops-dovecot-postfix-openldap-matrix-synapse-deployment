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

  services.nginx.virtualHosts."${fqdn}".enableACME = true;
  services.nginx.virtualHosts."${opt.matrix.synapse.fqdn}".useACMEHost = fqdn;
  services.nginx.virtualHosts."${opt.matrix.element.fqdn}".useACMEHost = fqdn;

  security.acme = {
    acceptTerms = true;
    email = "admin@ngse.de";
    defaults.email = "admin@ngse.de";
    preliminarySelfsigned = opt.acme.preliminarySelfsigned;
    certs."${fqdn}".extraDomainNames = opt.acme.aliases;
    #deprecation detected 2020-12-24 certs."${fqdn}".allowKeysForGroup = true;
  } // lib.optionalAttrs (!opt.acme.production) {
    defaults.server = https://acme-staging-v02.api.letsencrypt.org/directory;
  };

  systemd.services."acme-${fqdn}".enable = opt.acme.production;
  systemd.timers."acme-${fqdn}".enable = opt.acme.production;
  systemd.targets."acme-finished-${fqdn}" =
    let
      deps = [ "acme-selfsigned-${fqdn}.service" ]
        ++ lib.optionals opt.acme.production [ "acme-${fqdn}.service" ];
    in
    lib.mkForce {
      wantedBy = [ "default.target" ];
      requires = deps;
      after = deps;
    };
}

{ pkgs, lib, config, ...}:
let
  fqdn = config.networking.hostName;
  opt = import (./. + "/options/${fqdn}.nix") { fqdn = fqdn; };
in with lib; {

  environment.systemPackages = with pkgs; [
    #openldap
  ];

  nixpkgs.config.packageOverrides = pkgs: with pkgs; rec {
    matrix-synapse = pkgs.matrix-synapse.overrideDerivation (attrs: rec {
      name = "matrix-synapse-${version}";
      version = "0.33.3.1";

      src = fetchFromGitHub {
        owner = "matrix-org";
        repo = "synapse";
        rev = "v${version}";
        sha256 = "0q7rjh2qwj1ym5alnv9dvgw07bm7kk7igfai9ix72c6n7qb4z4i3";
      };
    });
  };

  services.nginx.virtualHosts."${opt.matrix-synapse.serverName}" = {
    forceSSL = true;
    useACMEHost = fqdn;
    locations = {
      "/_matrix" = {
        proxyPass = "http://localhost:8008";
        extraConfig = ''
          proxy_set_header X-Forwarded-For $remote_addr;
        '';
      };
    };
  };

  users.users."matrix-synapse".extraGroups = [ "nginx" ];

  services.matrix-synapse = {
    enable = true;
    enable_registration = false;
    database_type = "sqlite3";
    listeners =  [
      {
        bind_address = "localhost";
        port = 8008;
        resources = [
          {
            compress = true;
            names = [ "client" "webclient" ];
          } {
            compress = false;
            names = [ "federation" ];
          }
        ];
        tls = false;
        type = "http";
        x_forwarded = true;
      }
    ];
    max_upload_size = "10M";
    no_tls = true;
    public_baseurl = "https://${opt.matrix-synapse.serverName}/";
    registration_shared_secret = "$(opt.matrix-synapse.registrationSharedSecret)";
    server_name = "${fqdn}"; #"${opt.matrix-synapse.serverName}";
    tls_certificate_path = "${config.security.acme.directory}/${fqdn}/fullchain.pem";
    #tls_private_key_path = "${config.security.acme.directory}/${fqdn}/key.pem";
    web_client = true;
  };

  systemd.services.matrix-synapse.postStart = ''
    #${config.services.matrix-synapse.package}/bin/register_new_matrix_user -u test -p lalala -a -k ${opt.matrix-synapse.registrationSharedSecret} http://localhost:8008
  '';
}

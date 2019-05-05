{ pkgs, lib, config, ...}:
let
  fqdn = config.networking.hostName;
  opt = import (./. + "/options/${fqdn}.nix") { fqdn = fqdn; };
in with lib; {

  environment.systemPackages = with pkgs; [
    #openldap
  ];

  nixpkgs.config.packageOverrides = pkgs: with pkgs; rec {
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_11;
    extraConfig = ''
      synchronous_commit = off
    '';
  };

  services.nginx.virtualHosts."${opt.matrix-synapse.serverName}" = {
    forceSSL = true;
    useACMEHost = fqdn;
    locations = {
      "/_matrix" = {
        proxyPass = "http://127.0.0.1:8008";
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
    database_type = "psycopg2";
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
    registration_shared_secret = opt.matrix-synapse.registrationSharedSecret;
    server_name = "${fqdn}"; #"${opt.matrix-synapse.serverName}";
    tls_certificate_path = "${config.security.acme.directory}/${fqdn}/fullchain.pem";
    #tls_private_key_path = "${config.security.acme.directory}/${fqdn}/key.pem";
    web_client = true;
  };

  systemd.services.matrix-synapse.postStart =
    with opt.matrix-synapse; lib.optionalString registerTestUser ''
      ${config.services.matrix-synapse.package}/bin/register_new_matrix_user -u ${testUser} -p ${testPass} -k ${registrationSharedSecret} --no-admin https://${fqdn} || true
    '';
}

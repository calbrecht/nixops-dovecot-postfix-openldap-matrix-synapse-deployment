{ pkgs, lib, config, ... }:
let
  opt = import ./options.nix { inherit config; };
  fqdn = opt.fqdn;
in
with lib; {

  environment.systemPackages = with pkgs; [
    #openldap
  ];

  nixpkgs.config.packageOverrides = pkgs: with pkgs; rec { };

  networking.firewall = {
    allowedTCPPorts = [ 3478 3479 5349 5350 ];
    allowedUDPPorts = [ 3478 3479 5349 5350 ];
    allowedUDPPortRanges = [{ from = 50000; to = 54999; }];
  };

  services = {
    postgresql = {
      enable = true;
      # ! good to know ! wiped the existing db
      initialScript = pkgs.writeText "synapse-init.sql" ''
        CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
        CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
      '';
      package = pkgs.postgresql_11;
      settings = {
        synchronous_commit = false;
      };
    };

    nginx = {
      #https://nixos.org/manual/nixos/stable/index.html#module-services-matrix
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      recommendedProxySettings = true;

      logError = "stderr debug";

      virtualHosts = {
        "${fqdn}" = {
          addSSL = true;
          locations."= /.well-known/matrix/server".extraConfig = ''
            add_header Content-Type application/json;
            return 200 '${builtins.toJSON {
              "m.server" = "${opt.matrix.synapse.fqdn}:443";
            }}';
          '';
          locations."= /.well-known/matrix/client".extraConfig = ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            return 200 '${builtins.toJSON {
              "m.homeserver" = {
                "base_url" = "https://${opt.matrix.synapse.fqdn}";
              };
              "m.identity_server" = {
                #"base_url" = "https://vector.im";
                "base_url" = "https://${opt.matrix.synapse.fqdn}";
              };
            }}';
          '';
        };
        "${opt.matrix.synapse.fqdn}" = {
          forceSSL = true;
          locations."/".extraConfig = "return 302 https://${opt.matrix.element.fqdn};";
          locations."/_matrix" = {
            proxyPass = "http://127.0.0.1:8008";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-For $remote_addr;
            '';
            priority = 30;
          };
          locations."/_matrix/identity" = {
            proxyPass = "http://127.0.0.1:8090";
            extraConfig = ''
              #add_header Access-Control-Allow-Origin *;
              #add_header Access-Control-Allow-Method 'GET, POST, PUT, DELETE, OPTIONS';
              #proxy_set_header Host $host;
              #proxy_set_header X-Forwarded-For $remote_addr;
            '';
            priority = 20;
          };
          locations."/_matrix/client/r0/user_directory" = {
            proxyPass = "http://127.0.0.1:8090";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-For $remote_addr;
            '';
            priority = 10;
          };
        };
        "${opt.matrix.element.fqdn}" = {
          forceSSL = true;
          root = pkgs.element-web.override {
            # https://github.com/vector-im/element-web/blob/develop/docs/config.md
            conf = {
              default_server_config."m.homeserver" = {
                "base_url" = "https://${opt.matrix.synapse.fqdn}";
                "server_name" = "${fqdn}";
              };
              default_server_config."m.identity_server" = {
                "base_url" = "https://${opt.matrix.synapse.fqdn}";
              };
              default_theme = "dark";
              features = {
                feature_new_spinner = true;
                feature_pinning = true;
                feature_many_integration_managers = true;
                feature_presence_in_room_list = true;
                feature_latex_maths = true;
              };
              roomDirectory.servers = [
                opt.matrix.synapse.fqdn
                "matrix.mayflower.de"
                "matrix.org"
              ];
              defaultCountryCode = "DE";
              showLabsSettings = true;
              disable_custom_urls = true;
              permalinkPrefix = "https://${opt.matrix.element.fqdn}";
            };
          };
          locations."/".index = "index.html";
        };
      };
    };

    matrix-synapse = {
      enable = true;
      enable_registration = false;
      enable_metrics = false;
      database_type = "psycopg2";
      listeners = [
        {
          bind_address = "localhost";
          port = 8008;
          resources = [{
            compress = false;
            names = [ "client" "federation" ];
          }];
          tls = false;
          type = "http";
          x_forwarded = true;
        }
      ];
      max_upload_size = "10M";
      no_tls = true;
      public_baseurl = "https://${opt.matrix.synapse.fqdn}/";
      registration_shared_secret = opt.matrix.synapse.registrationSharedSecret;
      server_name = "${fqdn}"; #"${opt.matrix.synapse.fqdn}";
      tls_certificate_path = "${config.security.acme.certs."${fqdn}".directory}/fullchain.pem";
      #tls_private_key_path = "${config.security.acme.certs."${fqdn}".directory}/key.pem";
      turn_uris = [
        "turn:${fqdn}:3478?transport=udp"
        "turn:${fqdn}:3478?transport=tcp"
      ];
      turn_shared_secret = opt.turn.authSecret;
      turn_user_lifetime = "86400000";
      #deprecation detected 2020-12-24 web_client = true;
      #deprecated 2019-10-14 trusted_third_party_id_servers = [ fqdn ];
      verbose = "0";
    };

    mxisd = {
      enable = true;
      package = pkgs.ma1sd;
      matrix.domain = fqdn;
      server.name = opt.matrix.synapse.fqdn;
      server.port = 8090;
      extraConfig = {
        dns.overwrite.homeserver.client = [
          { name = opt.matrix.synapse.fqdn; value = "http://127.0.0.1:8008"; }
        ];
        session.policy.validation = {
          enabled = true;
          forLocal = {
            enabled = true;
            toLocal = true;
            toRemote.enabled = false;
          };
          forRemote = {
            enabled = true;
            toLocal = true;
            toRemote.enabled = false;
          };
        };
      };
    };

    coturn = {
      enable = true;
      listening-ips = [ ];
      lt-cred-mech = true;
      use-auth-secret = true;
      static-auth-secret = opt.turn.authSecret;
      realm = fqdn;
      cert = "${config.security.acme.certs."${fqdn}".directory}/fullchain.pem";
      pkey = "${config.security.acme.certs."${fqdn}".directory}/key.pem";
      min-port = 50000;
      max-port = 54999;
      no-tcp-relay = true;
      extraConfig = ''
        user-quota=12 # 4 streams per video call, so 12 streams = 3 simultaneous relayed calls per user.
        total-quota=1200
      '';
    };
  };

  systemd.services.matrix-synapse.postStart =
    with opt.matrix.synapse; lib.optionalString registerTestUser ''
      ${config.services.matrix-synapse.package}/bin/register_new_matrix_user -u ${testUser} -p ${testPass} -k ${registrationSharedSecret} --no-admin http://localhost:8008 || true
    '';

  users.extraGroups.nginx.members = [
    "matrix-synapse"
    "turnserver"
  ];
}

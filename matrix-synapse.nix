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
      package = pkgs.postgresql_11;
      settings = {
        synchronous_commit = false;
      };
    };

    nginx.virtualHosts = {
      "${opt.matrix-synapse.serverName}" = {
        forceSSL = true;
        useACMEHost = fqdn;
        locations = {
          "/".extraConfig = "return 302 https://riot.${fqdn};";
          "/_matrix" = {
            proxyPass = "http://127.0.0.1:8008";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-For $remote_addr;
            '';
            priority = 30;
          };
          "/_matrix/identity" = {
            proxyPass = "http://127.0.0.1:8090/_matrix/identity";
            extraConfig = ''
              add_header Access-Control-Allow-Origin *;
              add_header Access-Control-Allow-Method 'GET, POST, PUT, DELETE, OPTIONS';
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-For $remote_addr;
            '';
            priority = 20;
          };
          "/_matrix/client/r0/user_directory" = {
            proxyPass = "http://127.0.0.1:8090/_matrix/client/r0/user_directory";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Forwarded-For $remote_addr;
            '';
            priority = 10;
          };
        };
      };
      "riot.${fqdn}" = {
        forceSSL = true;
        useACMEHost = fqdn;

        locations = {
          "/" = {
            root = pkgs.element-web.override {
              #welcomePageUrl = "home.html";
              conf = {
                "default_hs_url" = "https://${fqdn}";
                "default_is_url" = "https://${fqdn}";
                "disable_custom_urls" = true;
                "disable_guests" = true;
                "disable_login_language_selector" = false;
                "disable_3pid_login" = true;
                "brand" = "Riot";
                "integrations_ui_url" = "https://scalar.vector.im/";
                "integrations_rest_url" = "https://scalar.vector.im/api";
                "integrations_jitsi_widget_url" = "https://scalar.vector.im/api/widgets/jitsi.html";
                "features" = {
                  "feature_groups" = "enable";
                  "feature_pinning" = "enable";
                  "feature_reactions" = "enable";
                };
                "default_federate" = true;
                "default_theme" = "dark";
                "roomDirectory" = {
                  "servers" = [
                    fqdn
                    "matrix.mayflower.de"
                    "matrix.org"
                  ];
                };
                "welcomeUserId" = null;
                "piwik" = false;
                "enable_presence_by_hs_url" = {
                  "https://matrix.org" = false;
                };
              };

              #conf = ''
              #  {
              #  "default_hs_url": "https://${fqdn}",
              #  "default_is_url": "https://${fqdn}",
              #  "disable_custom_urls" true,
              #  "disable_guests": true,
              #  "disable_login_language_selector": false,
              #  "disable_3pid_login": true,
              #  "brand": "Riot",
              #  "integrations_ui_url": "https://scalar.vector.im/",
              #  "integrations_rest_url": "https://scalar.vector.im/api",
              #  "integrations_jitsi_widget_url": "https://scalar.vector.im/api/widgets/jitsi.html",
              #  "features": {
              #  "feature_groups": "enable",
              #  "feature_pinning": "enable",
              #  "feature_reactions": "enable"
              #  };
              #  "default_federate": true,
              #  "default_theme": "dark",
              #  "roomDirectory": {
              #  "servers": [
              #  "${fqdn}", "matrix.mayflower.de", "matrix.org"
              #  ]
              #  };
              #  "welcomeUserId": null,
              #  "piwik": false,
              #  "enable_presence_by_hs_url": {
              #  "https://matrix.org": false
              #  }
              #  }
              #'';
            };
          };
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
          resources = [
            {
              compress = true;
              names = [ "client" "webclient" ];
            }
            {
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
    };

    mxisd = {
      enable = true;
      matrix.domain = fqdn;
      extraConfig = {
        dns.overwrite.homeserver.client = [
          { name = opt.matrix-synapse.serverName; value = "http://127.0.0.1:8008"; }
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
    with opt.matrix-synapse; lib.optionalString registerTestUser ''
      ${config.services.matrix-synapse.package}/bin/register_new_matrix_user -u ${testUser} -p ${testPass} -k ${registrationSharedSecret} --no-admin https://${fqdn} || true
    '';

  users.extraGroups.nginx.members = [
    "matrix-synapse"
    "turnserver"
  ];
}

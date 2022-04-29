{ pkgs, lib, config, ... }:
let
  opt = import ./options.nix { inherit config; };
  fqdn = opt.fqdn;
  matrix-synapse-rest-password-provider = with pkgs; python3Packages.buildPythonPackage rec {
    pname = "matrix-synapse-rest-password-provider";
    version = "0.1.4";

    src = fetchFromGitHub {
      owner = "ma1uta";
      repo = pname;
      rev = "c782c84aeab1872e73b6c29aadb99d3852e26bbd";
      sha256 = "sha256-XkLKX2uVqg43MJFXVF2P6lImEcswIqALwD6FZBoAKW0=";
    };

    patches = [
      (pkgs.fetchurl {
        url = "https://patch-diff.githubusercontent.com/raw/ma1uta/matrix-synapse-rest-password-provider/pull/8.patch";
        sha256 = "sha256-BwVBiikXhH2xsWr3N3HhHFynOJnH+egbz7uk0+2S4aw=";
      })
    ];
  };
  dc = "DC=" + lib.concatStringsSep ",DC=" (lib.splitString "." fqdn);
in
with lib; {

  environment.systemPackages = with pkgs; [
    #openldap
    #matrix-synapse-rest-password-provider
  ];

  #nixpkgs.config.packageOverrides = pkgs: with pkgs; rec {};

  networking.firewall = {
    allowedTCPPorts = [ 3478 3479 5349 5350 8448 ];
    allowedUDPPorts = [ 3478 3479 5349 5350 ];
    allowedUDPPortRanges = [{ from = 50000; to = 54999; }];
  };

  services = {
    postgresql = {
      enable = true;
      # ! good to know ! wiped the existing db
      initialScript = with opt.postgres.matrix-synapse; pkgs.writeText "synapse-init.sql" ''
        CREATE ROLE "${user}" WITH LOGIN PASSWORD '${password}';
        CREATE DATABASE "${database}" WITH OWNER "${user}"
        ENCODING 'UTF8'
        LC_COLLATE = "C"
        LC_CTYPE = "C"
        TEMPLATE template0;
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

      #upstreams = {
      #  _matrix = {
      #    extraConfig = ''
      #      rewrite ^ $request_uri;
      #      rewrite ^/_matrix/(.*) $1 break;
      #      return 400; #if the second rewrite won't match
      #      proxy_pass http://127.0.0.1:8008/_matrix/$uri;
      #    '';
      #  };
      #};

      virtualHosts = {
        "${fqdn}" = {
          addSSL = true;
          locations."= /.well-known/matrix/server".extraConfig = ''
            add_header Content-Type application/json;
            return 200 '${builtins.toJSON {
              "m.server" = "${opt.matrix.synapse.fqdn}:8448";
            }}';
          '';
          locations."= /.well-known/matrix/client".extraConfig = ''
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin 'https://${opt.matrix.element.fqdn}';
            add_header Access-Control-Allow-Method 'GET, OPTIONS';
            add_header Access-Control-Allow-Headers '*';
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
          listen = [
            { addr = "0.0.0.0"; port = 8448; ssl = true; }
            { addr = "[::0]"; port = 8448; ssl = true; }
            { addr = "0.0.0.0"; port = 443; ssl = true; }
            { addr = "[::0]"; port = 443; ssl = true; }
          ];
          locations."/" = {
            extraConfig = "return 302 https://${opt.matrix.element.fqdn};";
            priority = 40;
          };
          locations."~ ^/_matrix/(.*)$" = {
            proxyPass = "http://127.0.0.1:8008";
            extraConfig = ''
            '';
            priority = 30;
          };
          locations."~ ^/_matrix/identity/(.*)$" = {
            proxyPass = "http://127.0.0.1:8090";
            extraConfig = ''
            '';
            priority = 20;
          };
          locations."~ ^/_matrix/client/r0/user_directory/(.*)$" = {
            proxyPass = "http://127.0.0.1:8090";
            extraConfig = ''
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
                fqdn
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
          extraConfig = ''
            add_header Access-Control-Allow-Origin 'https://${opt.matrix.element.fqdn}';
            add_header Access-Control-Allow-Method '*';
            add_header Access-Control-Allow-Headers '*';
          '';
        };
      };
    };

    matrix-synapse = {
      enable = true;
      plugins = with pkgs; [
        matrix-synapse-rest-password-provider
      ];
      settings = {
        max_upload_size = "10M";
        database.name = "psycopg2";
        database.args = with opt.postgres.matrix-synapse; {
          inherit database user password;
        };
        enable_registration = false;
        enable_metrics = false;
        server_name = "${fqdn}"; #"${opt.matrix.synapse.fqdn}";
        public_baseurl = "https://${opt.matrix.synapse.fqdn}/";
        turn_uris = [
          "turn:${fqdn}:3478?transport=udp"
          "turn:${fqdn}:3478?transport=tcp"
        ];
        turn_user_lifetime = "86400000";
        turn_shared_secret = opt.turn.authSecret;
        tls_certificate_path = "${config.security.acme.certs."${fqdn}".directory}/fullchain.pem";
        tls_private_key_path = "${config.security.acme.certs."${fqdn}".directory}/key.pem";
        listeners = [
          #{
          #  bind_addresses = [ "::" "0.0.0.0" ];
          #  port = 8448;
          #  resources = [
          #    { names = [ "federation" ]; compress = false; }
          #  ];
          #  tls = true;
          #  type = "http";
          #  x_forwarded = false;
          #}
          {
            bind_addresses = [ "localhost" ];
            port = 8008;
            resources = [
              #{ names = [ "client" ]; compress = false; }
              { names = [ "client" "federation" ]; compress = false; }
            ];
            tls = false;
            type = "http";
            x_forwarded = true;
          }
        ];
      };
      extraConfigFiles = [
        (pkgs.writeTextFile {
          name = "matrix-synapse-extra-config.yml";
          text = ''
            registration_shared_secret: ${opt.matrix.synapse.registrationSharedSecret}
            password_providers:
              - module: "rest_auth_provider.RestAuthProvider"
                config:
                  endpoint: "http://127.0.0.1:8090"
          '';
        })
      ];
      #deprecation detected 2022-04-28 no_tls = true;
      #deprecation detected registration_shared_secret = opt.matrix.synapse.registrationSharedSecret;
      #deprecation detected 2020-12-24 web_client = true;
      #deprecated 2019-10-14 trusted_third_party_id_servers = [ fqdn ];
      #deprecation detected verbose = "0";
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
        ldap = {
          enabled = true;
          connection = {
            host = "127.0.0.1";
            port = 389;
            bindDn = "UID=matrix,OU=services,${dc}";
            bindPassword = opt.matrix.dnpass;
            baseDNs = [ "OU=people,${dc}" ];
          };
          attribute = {
            uid = { type = "uid"; value = "uid"; };
            name = "cn";
            threepid = { email = [ "mail" ]; };
          };
        };
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

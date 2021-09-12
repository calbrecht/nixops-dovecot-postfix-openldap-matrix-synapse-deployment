{ pkgs, lib, config, ... }:
let
  opt = import ./options.nix { inherit config; };
  fqdn = opt.fqdn;
  cfg = config.services.openldap // {
    confDir = "/etc/openldap/slapd.d";
    proto = "ldap://127.0.0.1";
  };
  dc = "dc=" + lib.concatStringsSep ",dc=" (lib.splitString "." fqdn);
  #db-0-init = (builtins.readFile ./etc/ldap/slapcat.0.ldif);
  vmailUser = config.users.users."${config.services.dovecot2.mailUser}";
  vmailGroup = config.users.groups."${config.services.dovecot2.mailGroup}";
in
with lib; {

  environment.systemPackages = with pkgs; [
    openldap
  ];

  nixpkgs.config.packageOverrides = pkgs: with pkgs; rec {
    openldap = pkgs.openldap.overrideDerivation (attrs: {
      configureFlags = attrs.configureFlags ++ [
        "--enable-crypt"
        "--enable-spasswd"
      ];
    });
  };

  services.openldap = {
    enable = true;
    # deprecation detected 2020-12-24 rootdn = "cn=fake,cn=${opt.openldap.rootCN},${dc}";
    # deprecation detected 2020-12-24 rootpw = "fake";
    # deprecation detected 2020-12-24 suffix = dc;
    # deprecation detected 2020-12-24 database = "hdb";
    settings = {
      attrs = {
        olcArgsFile = "/run/slapd/slapd.args";
        olcLogLevel = "none";
        olcPidFile = "/run/slapd/slapd.pid";
        olcToolThreads = "1";
      };
      children = {
        "cn=schema" = {
          attrs = {
            objectClass = "olcSchemaConfig";
            cn = "schema";
          };
          includes = [
            "${pkgs.openldap}/etc/schema/core.ldif"
            "${pkgs.openldap}/etc/schema/cosine.ldif"
            "${pkgs.openldap}/etc/schema/nis.ldif"
            "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
            ./etc/ldap/postfix-book.ldif
          ];
        };
        "olcBackend={0}hdb" = {
          attrs = {
            objectClass = "olcBackendConfig";
            olcBackend = "{0}hdb";
          };
        };
        "olcDatabase={-1}frontend" = {
          attrs = {
            objectClass = [ "olcDatabaseConfig" "olcFrontendConfig" ];
            olcDatabase = "{-1}frontend";
            olcAccess = [
              "{0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break"
              "{1}to dn.exact=\"\" by * read"
              "{2}to dn.base=\"cn=Subschema\" by * read"
            ];
            olcSizeLimit = "500";
          };
        };
        "olcDatabase={0}config" = {
          attrs = {
            objectClass = "olcDatabaseConfig";
            olcDatabase = "{0}config";
            olcAccess = "{0}to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break";
          };
        };
        "olcDatabase={1}hdb" = {
          attrs = {
            objectClass = [ "olcDatabaseConfig" "olcHdbConfig" ];
            olcDatabase = "{1}hdb";
            olcDbDirectory = cfg.dataDir;
            olcSuffix = dc;
            olcAccess = [
              ''{0}to dn.subtree="${dc}" attrs=userPassword
            by self write
            by dn.base="cn=${opt.openldap.rootCN},${dc}" write
            by dn.children="ou=services,${dc}" read
            by anonymous auth
            by * none''
              ''{1}to dn.subtree="${dc}"
            by self read
            by dn.base="cn=${opt.openldap.rootCN},${dc}" write
            by dn.children="ou=services,${dc}" read
            by * none''
            ];
            olcLastMod = "TRUE";
            olcRootDN = "cn=${opt.openldap.rootCN},${dc}";
            olcRootPW = "${opt.openldap.rootPW}";
            olcDbCheckpoint = "512 30";
            olcDbConfig = [
              "{0}set_cachesize 0 2097152 0"
              "{1}set_lk_max_objects 1500"
              "{2}set_lk_max_locks 1500"
              "{3}set_lk_max_lockers 1500"
            ];
            olcDbIndex = "objectClass eq";
          };
        };
      };
    };
    declarativeContents = {
      "${dc}" = ''
        dn: ${dc}
        objectClass: top
        objectClass: dcObject
        objectClass: organization
        o: ${head (splitString "." fqdn)}
        dc: ${head (splitString "." fqdn)}

        dn: cn=${opt.openldap.rootCN},${dc}
        objectClass: simpleSecurityObject
        objectClass: organizationalRole
        cn: ${opt.openldap.rootCN}
        description: LDAP administrator
        userPassword:: ${opt.openldap.rootPW}

      '' +
      (concatStringsSep "\n" (mapAttrsToList
        (ouName: ouValues: ''
          dn: ou=${ouName},${dc}
          ou: ${ouName}
          objectClass: top
          objectClass: organizationalUnit

        ''
        + optionalString (ouName == "services") (concatStringsSep "\n"
          (mapAttrsToList
            (serviceName: servicePassword: ''
              dn: uid=${serviceName},ou=${ouName},${dc}
              uid: ${serviceName}
              objectClass: top
              objectClass: simpleSecurityObject
              objectClass: account
              userPassword:: ${servicePassword}
            '')
            ouValues)
        )
        + optionalString (ouName == "groups") (concatStringsSep "\n"
          (mapAttrsToList
            (groupName: groupValues: ''
              dn: cn=${groupName},ou=${ouName},${dc}
              cn: ${groupName}
              objectClass: posixGroup
              gidNumber: ${toString groupValues.gidNumber}
              ${concatStringsSep "\n" (map (name: "memberUid: " + name) groupValues.memberUid)}
            '')
            ouValues)
        )
        + optionalString (ouName == "people") (concatStringsSep "\n"
          (mapAttrsToList
            (peopleName: peopleValues: ''
              dn: uid=${peopleName},ou=${ouName},${dc}
              uid: ${peopleName}
              objectClass: PostfixBookMailAccount
              objectClass: extensibleObject
              objectClass: person
              mail: ${peopleName}@${fqdn}
              sn: ${peopleValues.sn}
              cn: ${peopleValues.givenName} ${peopleValues.sn}
              mailUidNumber: ${toString vmailUser.uid}
              userPassword:: ${peopleValues.userPassword}
              mailHomeDirectory: ${vmailUser.home}/${peopleName}@${fqdn}
              mailEnabled: ${if peopleValues.mailEnabled then "TRUE" else "FALSE"}
              givenName: ${peopleValues.givenName}
              mailGidNumber: ${toString vmailGroup.gid}
              mailStorageDirectory: maildir:${vmailUser.home}/${peopleName}@${fqdn}/Maildir
              mailQuota: ${toString peopleValues.mailQuota}
              ${concatStringsSep "\n" (map (n: "mailAlias: " + n + "@" + fqdn) peopleValues.mailAlias)}
            '')
            ouValues)
        )
        )
        opt.openldap.ou));
    };
  };

  systemd.services = {
    #slapadd = {
    #  preStart = ''
    #    mkdir -p ${cfg.confDir}
    #    rm -fr ${cfg.confDir}/cn\=config*
    #    rm -fr ${cfg.dataDir}
    #    mkdir -p ${cfg.dataDir}
    #    chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
    #  '';
    #  postStart = ''
    #    chown -R ${cfg.user}:${cfg.group} ${cfg.confDir}
    #  '';
    #  serviceConfig = {
    #    Type = "oneshot";
    #    ExecStart = [
    #      "-${pkgs.openldap.out}/bin/slapadd -F${cfg.confDir} -n0 -l/etc/openldap/db.0.ldif"
    #      "-${pkgs.openldap.out}/bin/slapadd -F${cfg.confDir} -n1 -l/etc/openldap/db.1.ldif"
    #    ];
    #  };
    #};
    openldap = {
      #wants = [ "slapadd.service" ];
      #after = [ "slapadd.service" ];
      serviceConfig = {
        #ldapsearch -x -W -D uid=dovecot,ou=services,dc=ngse,dc=dedyn,dc=io,dc=de -b ou=people,dc=ngse,dc=dedyn,dc=io,dc=de
        Type = "forking";
        PIDFile = "/run/slapd/slapd.pid";
        ExecStart = pkgs.lib.mkForce "${pkgs.openldap.out}/libexec/slapd -u ${cfg.user} -g ${cfg.group} -F ${cfg.confDir} -h ${cfg.proto}";
      };
    };
  };
  #environment.etc."openldap/postfix-book.ldif" = {
  #  mode = "0755";
  #  text = builtins.readFile ./etc/ldap/postfix-book.ldif;
  #};
  #environment.etc = {
  #  "openldap/db.0.ldif" = {
  #    mode = "0600";
  #    text = db-0-init + ''
  #      dn: olcDatabase={1}hdb,cn=config
  #      objectClass: olcDatabaseConfig
  #      objectClass: olcHdbConfig
  #      olcDatabase: {1}hdb
  #      olcDbDirectory: ${cfg.dataDir}
  #      olcSuffix: ${dc}
  #      olcAccess: {0}to dn.subtree="${dc}" attrs=userPassword
  #        by self write
  #        by dn.base="cn=${opt.openldap.rootCN},${dc}" write
  #        by dn.children="ou=services,${dc}" read
  #        by anonymous auth
  #        by * none
  #      olcAccess: {1}to dn.subtree="${dc}"
  #        by self read
  #        by dn.base="cn=${opt.openldap.rootCN},${dc}" write
  #        by dn.children="ou=services,${dc}" read
  #        by * none
  #      olcLastMod: TRUE
  #      olcRootDN: cn=${opt.openldap.rootCN},${dc}
  #      olcRootPW:: ${opt.openldap.rootPW}
  #      olcDbCheckpoint: 512 30
  #      olcDbConfig: {0}set_cachesize 0 2097152 0
  #      olcDbConfig: {1}set_lk_max_objects 1500
  #      olcDbConfig: {2}set_lk_max_locks 1500
  #      olcDbConfig: {3}set_lk_max_lockers 1500
  #      olcDbIndex: objectClass eq
  #    '';
  #    uid = config.ids.uids.openldap;
  #    gid = config.ids.gids.openldap;
  #  };
  #  "openldap/db.1.ldif" = {
  #    mode = "0600";
  #    text = ''
  #              dn: ${dc}
  #              objectClass: top
  #              objectClass: dcObject
  #              objectClass: organization
  #              o: ${head (splitString "." fqdn)}
  #              dc: ${head (splitString "." fqdn)}
  #
  #              dn: cn=${opt.openldap.rootCN},${dc}
  #              objectClass: simpleSecurityObject
  #              objectClass: organizationalRole
  #              cn: ${opt.openldap.rootCN}
  #              description: LDAP administrator
  #              userPassword:: ${opt.openldap.rootPW}
  #
  #              ${concatStringsSep "\n" (mapAttrsToList
  #      (ouName: ouValues: ''
  #                  dn: ou=${ouName},${dc}
  #                  ou: ${ouName}
  #                  objectClass: top
  #                  objectClass: organizationalUnit
  #
  #                ''
  #                + optionalString (ouName == "services") (concatStringsSep "\n"
  #                    (mapAttrsToList
  #      (serviceName: servicePassword: ''
  #                      dn: uid=${serviceName},ou=${ouName},${dc}
  #                      uid: ${serviceName}
  #                      objectClass: top
  #                      objectClass: simpleSecurityObject
  #                      objectClass: account
  #                      userPassword:: ${servicePassword}
  #                    '')
  #      ouValues)
  #                )
  #                + optionalString (ouName == "groups") (concatStringsSep "\n"
  #                    (mapAttrsToList
  #      (groupName: groupValues: ''
  #                      dn: cn=${groupName},ou=${ouName},${dc}
  #                      cn: ${groupName}
  #                      objectClass: posixGroup
  #                      gidNumber: ${toString groupValues.gidNumber}
  #                      ${concatStringsSep "\n" (map (name: "memberUid: " + name) groupValues.memberUid)}
  #                    '')
  #      ouValues)
  #                )
  #                + optionalString (ouName == "people") (concatStringsSep "\n"
  #                    (mapAttrsToList
  #      (peopleName: peopleValues: ''
  #                      dn: uid=${peopleName},ou=${ouName},${dc}
  #                      uid: ${peopleName}
  #                      objectClass: PostfixBookMailAccount
  #                      objectClass: extensibleObject
  #                      objectClass: person
  #                      mail: ${peopleName}@${fqdn}
  #                      sn: ${peopleValues.sn}
  #                      cn: ${peopleValues.givenName} ${peopleValues.sn}
  #                      mailUidNumber: ${toString vmailUser.uid}
  #                      userPassword:: ${peopleValues.userPassword}
  #                      mailHomeDirectory: ${vmailUser.home}/${peopleName}@${fqdn}
  #                      mailEnabled: ${if peopleValues.mailEnabled then "TRUE" else "FALSE"}
  #                      givenName: ${peopleValues.givenName}
  #                      mailGidNumber: ${toString vmailGroup.gid}
  #                      mailStorageDirectory: maildir:${vmailUser.home}/${peopleName}@${fqdn}/Maildir
  #                      mailQuota: ${toString peopleValues.mailQuota}
  #                      ${concatStringsSep "\n" (map (n: "mailAlias: " + n + "@" + fqdn) peopleValues.mailAlias)}
  #                    '')
  #      ouValues)
  #                )
  #              )
  #      opt.openldap.ou)}
  #
  #    '';
  #    uid = config.ids.uids.openldap;
  #    gid = config.ids.gids.openldap;
  #  };
  #};
}

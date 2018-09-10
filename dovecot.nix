{ pkgs, lib, config, ...}:
let
  cfg = config.services.dovecot2;
  fqdn = config.networking.hostName;
  opt = import (./. + "/options/${fqdn}.nix") { fqdn = fqdn; };
  dc = "dc=" + lib.concatStringsSep ",dc=" (lib.splitString "." fqdn);
in {

  environment.systemPackages = with pkgs; [
  ];

  #nixpkgs.config.packageOverrides = pkgs: with pkgs; rec {
  #  postfix = pkgs.postfix.override {
  #    withLdap = true;
  #  };
  #};

  systemd.services.dovecot2.after = [ "openldap.service" "keys.target" "network.target" "acme-${fqdn}.service" ];
  systemd.services.dovecot2.wants = [ "openldap.service" "keys.target" "acme-${fqdn}.service" ];

  users.users."${cfg.mailUser}" = {
    createHome = true;
    isSystemUser = true;
    #group = "${cfg.mailGroup}";
    home = "${cfg.mailLocation}";
    uid = 5000;
  };
  users.groups."${cfg.mailGroup}" = {
    members = [ "${cfg.mailUser}" ];
    gid = 5000;
  };
  
  services.dovecot2 = with lib; rec {
    enable = true;
    enablePAM = false;
    enablePop3 = false;
    protocols = [ "lmtp" "sieve" ];
    mailUser = "vmail";
    mailGroup = "vmail";
    mailLocation = "/var/db/vmail";
    sslServerCert = "${config.security.acme.directory}/${fqdn}/fullchain.pem";
    sslServerKey = "${config.security.acme.directory}/${fqdn}/key.pem";
    modules = [ pkgs.dovecot_pigeonhole ];
    extraConfig = ''
      log_path = syslog
      syslog_facility = mail
      auth_debug = yes
      postmaster_address = postmaster@${fqdn}
      namespace {
        location = maildir:${cfg.mailLocation}/public:INDEXPVT=~/Maildir/public
        prefix = Public/
        separator = /
        subscriptions = no
        type = public
      }
      namespace inbox {
        inbox = yes
        location =
        mailbox Drafts {
          auto = subscribe
          special_use = \Drafts
        }
        mailbox Public {
          auto = subscribe
        }
        mailbox Sent {
          special_use = \Sent
        }
        mailbox "Sent Messages" {
          special_use = \Sent
        }
        mailbox Spam {
          auto = subscribe
          special_use = \Junk
        }
        mailbox Trash {
          auto = subscribe
          special_use = \Trash
        }
        prefix =
        separator = /
        subscriptions = yes
        type = private
      }
      userdb {
        args = /etc/dovecot/dovecot-ldap.conf.ext
        driver = ldap
      }
      passdb {
        args = /etc/dovecot/dovecot-ldap.conf.ext
        driver = ldap
      }
      plugin {
        sieve = ~/.dovecot.sieve
        sieve_dir = ~/sieve
      }
      service auth {
        unix_listener auth-userdb {
          group = ${cfg.mailGroup}
          mode = 0600
          user = ${cfg.mailUser}
        }
        unix_listener /var/lib/postfix/queue/private/auth {
          group = ${config.services.postfix.group}
          mode = 0600
          user = ${config.services.postfix.user}
        }
      }
      service imap-login {
        inet_listener imaps {
          port = 0
        }
      }
      protocol lmtp {
        mail_plugins = " sieve"
      }
      protocol lda {
        mail_plugins = " sieve"
      }
    '';
    sieveScripts."default" = pkgs.writeText "dovecot-sieve-default" ''
      require ["fileinto"];
      if header :contains "X-Spam-Flag" "YES" {
        fileinto "Spam";
        stop;
      }
    '';
    sieveScripts."before" = sieveScripts."default";
  };
  
  environment.etc."dovecot/dovecot-ldap.conf.ext" = {
    mode = "0600";
    text = ''
      hosts = 127.0.0.1
      dn = uid=dovecot,ou=services,${dc}
      dnpass = ${opt.dovecot.dnpass}
      ldap_version = 3
      base = ou=people,${dc}
      user_attrs = mailHomeDirectory=home,mailUidNumber=uid,mailGidNumber=gid,mailStorageDirectory=mail
      user_filter = (&(objectClass=PostfixBookMailAccount)(uid=%n))
      pass_attrs = uid=user,userPassword=password
      pass_filter = (&(objectClass=PostfixBookMailAccount)(uid=%n))
      default_pass_scheme = SSHA
    '';
    uid = config.ids.uids.dovecot2;
    gid = config.ids.gids.dovecot2;
  };
}

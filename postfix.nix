{ pkgs, lib, config, ... }:
let
  opt = import ./options.nix { inherit config; };
  fqdn = opt.fqdn;
  dc = "dc=" + lib.concatStringsSep ",dc=" (lib.splitString "." fqdn);
in
{

  environment.systemPackages = with pkgs; [
  ];

  nixpkgs.config.packageOverrides = pkgs: with pkgs; rec {
    postfix = pkgs.postfix.override {
      withLDAP = true;
    };
  };

  systemd.services.postfix.wants = [ "openldap.service" "acme-${fqdn}.service" ];
  systemd.services.postfix.after = [ "openldap.service" "acme-${fqdn}.service" "network.target" ];

  services.postfix = with lib; {
    enable = true;
    postmasterAlias = "";
    hostname = "mail.${fqdn}";
    networks= [ "127.0.0.1" ];
    domain = fqdn;
    destination = [
      #"$myhostname"
      "localhost.$mydomain"
      "localhost"
    ];
    extraConfig = ''

      # Greet connecting clients with this banner
      smtpd_banner = $myhostname ESMTP $mail_name (NixOS)

      # Do not append domain part to incomplete addresses (this is the MUA's job)
      append_dot_mydomain = no
      
      # Disable local transport (so that system accounts can't receive mail)
      local_transport = error:Local Transport Disabled

      # Deliver mail for virtual recipients to Dovecot
      virtual_transport = dovecot
 
      # Valid virtual domains
      virtual_mailbox_domains = ${fqdn}
 
      # Valid virtual recipients
      virtual_mailbox_maps = ldap:/etc/postfix_/ldap_virtual_recipients.cf
 
      # Virtual and local aliases
      alias_maps = ldap:/etc/postfix_/ldap_virtual_aliases.cf
      virtual_alias_maps = ldap:/etc/postfix_/ldap_virtual_aliases.cf

      smtpd_sender_login_maps = ldap:/etc/postfix_/ldap_virtual_senders.cf
       
      # Enable SASL (required for SMTP authentication)
      smtpd_sasl_auth_enable = yes

      smtpd_sasl_type = dovecot
      smtpd_sasl_path = private/auth
       
      # Enable SASL for Outlook-Clients as well
      broken_sasl_auth_clients = yes
 
      ### TLS ###
      # Enable TLS on smtp client
      smtp_tls_security_level = dane

      # Enable TLS (required to encrypt the plaintext SASL authentication)
      smtpd_tls_security_level = may
 
      # Only offer SASL in a TLS session
      smtpd_tls_auth_only = yes
 
      # Certification Authority
      #smtpd_tls_CAfile = /etc/postfix_/cacert.pem
 
      # Public Certificate
      smtpd_tls_cert_file = ${config.security.acme.directory}/${fqdn}/fullchain.pem
 
      # Private Key (without passphrase)
      smtpd_tls_key_file = ${config.security.acme.directory}/${fqdn}/key.pem
 
      # Randomizer for key creation
      tls_random_source = dev:/dev/urandom
 
      # TLS related logging (set to 2 for debugging)
      smtpd_tls_loglevel = 0
 
      # Avoid Denial-Of-Service-Attacks
      smtpd_client_new_tls_session_rate_limit = 10
 
      # Activate TLS Session Cache
      smtpd_tls_session_cache_database = btree:/var/lib/postfix/data/smtpd_session_cache
 
      # Deny some TLS-Ciphers
      smtpd_tls_exclude_ciphers =
        EXP
        EDH-RSA-DES-CBC-SHA
        ADH-DES-CBC-SHA
        DES-CBC-SHA
        SEED-SHA
        RC4
 
      # Diffie-Hellman Parameters for Perfect Forward Secrecy
      # Can be created with:
      # openssl dhparam -2 -out dh_512.pem 512
      # openssl dhparam -2 -out dh_1024.pem 1024
      #smtpd_tls_dh512_param_file = ''${config_directory}/certs/dh_512.pem
      #smtpd_tls_dh1024_param_file = ''${config_directory}/certs/dh_1024.pem
 
      # Recipient Restrictions (RCPT TO related)
      smtpd_recipient_restrictions =
              # Allow relaying for SASL authenticated clients and trusted hosts/networks
              # This can be put to smtpd_relay_restrictions in Postfix 2.10 and later 
              permit_sasl_authenticated
              reject_non_fqdn_recipient
              reject_unknown_recipient_domain
              reject_unauth_destination
              permit_mynetworks
              # Reject the following hosts
              check_sender_ns_access hash:/etc/postfix/check_sender_ns_access
              check_sender_mx_access hash:/etc/postfix/check_sender_mx_access
              # Additional blacklist
              reject_rbl_client ix.dnsbl.manitu.net
              # Finally permit (relaying still requires SASL auth)
              permit
       
      # Reject the request if the sender is the null address and there are multiple recipients
      smtpd_data_restrictions = reject_multi_recipient_bounce
       
      # Sender Restrictions
      smtpd_sender_restrictions =
              reject_non_fqdn_sender
              reject_unknown_sender_domain
              reject_unauthenticated_sender_login_mismatch
       
      # HELO/EHLO Restrictions
      smtpd_helo_restrictions =
      	      permit_mynetworks
              check_helo_access hash:/etc/postfix/check_helo_access
              #reject_non_fqdn_helo_hostname
              reject_invalid_hostname
       
      # Deny VRFY recipient checks
      disable_vrfy_command = yes
       
      # Require HELO
      smtpd_helo_required = yes
       
      # Reject instantly if a restriction applies (do not wait until RCPT TO)
      smtpd_delay_reject = no
       
      # Client Restrictions (IP Blacklist)
      smtpd_client_restrictions = check_client_access hash:/etc/postfix/check_client_access
      
      #milter_default_action = accept
      #milter_protocol = 6
      #milter_mail_macros = {auth_author} {auth_type} {auth_authen}
      
      #smtpd_milters = unix:/milter-manager/milter-manager.sock
      
      # set huge 100MB size limit
      message_size_limit = 104857600
      
    '';
    extraMasterConf = ''
      dovecot   unix  -       n       n       -       -       pipe
        flags=ODRhu user=vmail:vmail
        argv=${pkgs.dovecot}/libexec/dovecot/deliver -e -f ''${sender} -d ''${recipient}
    '';
    mapFiles."check_helo_access" = pkgs.writeText "postfix-check-helo-access" ''
        ${concatStringsSep "\n" (map (x: x + " REJECT forbidden") opt.postfix.helo.reject)}
    '';
    mapFiles."check_sender_ns_access" = pkgs.writeText "postfix-check-sender-ns-access" ''
        ${concatStringsSep "\n" (map (x: x + " REJECT forbidden") opt.postfix.sender.ns.reject)}
    '';
    mapFiles."check_sender_mx_access" = pkgs.writeText "postfix-check-sender-mx-access" ''
        ${concatStringsSep "\n" (map (x: x + " REJECT forbidden") opt.postfix.sender.mx.reject)}
    '';
    mapFiles."check_client_access" = pkgs.writeText "postfix-check-client-access" ''
        ${concatStringsSep "\n" (map (x: x + " REJECT forbidden") opt.postfix.client.reject)}
    '';
  };
  
  environment.etc."postfix_/ldap_virtual_recipients.cf" = {
    mode = "0600";
    text = ''
      bind = yes
      bind_dn = uid=postfix,ou=services,${dc}
      bind_pw = ${opt.postfix.ldap.bind.pw}
      server_host = ldap://127.0.0.1:389
      search_base = ou=people,${dc}
      version = 3
      domain = ${fqdn}
      query_filter = (&(mail=%s)(mailEnabled=TRUE))
      result_attribute = mail
    '';
    uid = config.ids.uids.postfix;
    gid = config.ids.gids.postfix;
  };
  environment.etc."postfix_/ldap_virtual_senders.cf" = {
    mode = "0600";
    text = ''
      bind = yes
      bind_dn = uid=postfix,ou=services,${dc}
      bind_pw = ${opt.postfix.ldap.bind.pw}
      server_host = ldap://127.0.0.1:389
      search_base = ou=people,${dc}
      version = 3
      domain = ${fqdn}
      query_filter = (&(|(mail=%s)(mailAlias=%s))(mailEnabled=TRUE))
      result_attribute = uid
    '';
    uid = config.ids.uids.postfix;
    gid = config.ids.gids.postfix;
  };
  environment.etc."postfix_/ldap_virtual_aliases.cf" = {
    mode = "0600";
    text = ''
      bind = yes
      bind_dn = uid=postfix,ou=services,${dc}
      bind_pw = ${opt.postfix.ldap.bind.pw}
      server_host = ldap://127.0.0.1:389
      search_base = ou=people,${dc}
      version = 3
      domain = ${fqdn}
      query_filter = (&(mailAlias=%s)(mailEnabled=TRUE))
      result_attribute = mail, email
    '';
    uid = config.ids.uids.postfix;
    gid = config.ids.gids.postfix;
  };
}

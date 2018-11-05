{ fqdn }:

rec {
  ip = "192.168.122.9";

  acme = {
    preliminarySelfsigned = true;
    production = false;
    aliases = [ ];
  };

  matrix-synapse = {
    serverName = "matrix.${fqdn}";
    registrationSharedSecret = "ojsCMkWjHFEOT65G0TlcNYW6UNtjtv7YfEH4bwrEO9elVZYW7i";
    registerTestUser = true;
    testUser = "t4";
    testPass = "test4me";
  };
  
  openldap = {
    ou = {
      services = {
        #slappasswd -nh "{SSHA}" | base64
        postfix = "e1NTSEF9VkN2QThlUG9HR0hmWmdLT3dOM1RBZEhDTW5JRGN5b04=";
        dovecot = "e1NTSEF9VkN2QThlUG9HR0hmWmdLT3dOM1RBZEhDTW5JRGN5b04=";
      };
      people = {
        t1 = {
          sn = "1";
          givenName = "t";
          userPassword = "e1NTSEF9LzlZM2pTVkdPelhxSm5Jd3RnM0t0UlZ2RnlWazNZVCs=";
          mailEnabled = true;
          mailAlias = [ "t2" "t3" ];
          mailQuota = 10240;
        };
        t4 = {
          sn = "4";
          givenName = "t";
          userPassword = "e1NTSEF9LzlZM2pTVkdPelhxSm5Jd3RnM0t0UlZ2RnlWazNZVCs=";
          mailEnabled = true;
          mailAlias = [ "t5" ];
          mailQuota = 10240;
        };
      };
      groups = {
        g1 = {
          gidNumber = 10000;
          memberUid = [ "t1" "t2" ];
        };
      };
    };
    rootCN = "admin";
    rootPW = "e1NTSEF9QVl3OXcwdzg3R21veWF2T3VYVHd1VE1Va1grOHVLWEg=";
  };

  postfix = {
    ldap.bind.pw = "e1NTSEF9LzlZM2pTVkdPelhxSm5Jd3RnM0t0UlZ2RnlWazNZVCs=";
    helo.reject = [ ip fqdn ];
    sender = {
      ns.reject = [];
      mx.reject = [];
    };
    client.reject = [];
  };

  dovecot.dnpass = "e1NTSEF9LzlZM2pTVkdPelhxSm5Jd3RnM0t0UlZ2RnlWazNZVCs=";

}

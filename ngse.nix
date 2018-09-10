{
  network.description = "Virtual server";

  ngse = { config, pkgs, ... }:
  {
    imports = [
      ./users.nix
      ./acme.nix
      ./openldap.nix
      ./postfix.nix
      ./dovecot.nix
      ./matrix-synapse.nix
    ];

    environment.systemPackages = with pkgs; [
      st
      sqlite
    ];

    nixpkgs = {
      config = {
        allowBroken = true;
        allowUnfree = true;
      };
      system = "x86_64-linux";
    };

    programs = {
      zsh = {
        enable = true;
        interactiveShellInit = ''
          precmd_functions=( vcs_info )
        '';
        promptInit = ''
          setopt prompt_subst
  
          zstyle ':vcs_info:*' enable git
  	  zstyle ':vcs_info:git*:*' get-revision true
  	  zstyle ':vcs_info:git*:*' check-for-changes true
  
  	  # hash changes branch misc
  	  zstyle ':vcs_info:git*' formats "(%s) %12.12i %c%u %b%m"
  	  zstyle ':vcs_info:git*' actionformats "(%s|%a) %12.12i %c%u %b%m"
  
  	  autoload -Uz vcs_info
  	
          export PROMPT='%f%F{%(!.red.green)}%m%f %F{yellow}%~%f $vcs_info_msg_0_%E
  %F{%(!.red.green)}%#%f%E '
        '';
      };
    };

    security.sudo.wheelNeedsPassword = true;

    services = {
      ntp.enable = false;
      chrony.enable = false;
  
      openssh = {
        enable = true;
        allowSFTP = false;
        permitRootLogin = "without-password";
        passwordAuthentication = false;
        challengeResponseAuthentication = false;
      };

      xserver.enable = false;
    };

    networking = {
      extraHosts = ''
        127.0.0.2 ${config.networking.hostName}
        127.0.0.3 matrix.${config.networking.hostName}
      '';
      firewall = {
        allowedUDPPorts = [ ];
        allowedTCPPorts = [ 22 25 80 143 443 8448 ];
        allowPing = true;
      };
    };

    time.timeZone = "Europe/Berlin";
  
    users = {
      defaultUserShell = "/run/current-system/sw/bin/zsh";
    };
  };
}

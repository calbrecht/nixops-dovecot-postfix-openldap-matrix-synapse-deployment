flakes @ { self, nixpkgs, ... }:

{
  network = {
    description = "Virtual server";
    storage.legacy = {};
  };

  ngse = { config, pkgs, ... }:
  {
    deployment = {
      targetEnv = "libvirtd";
      libvirtd = {
        headless = true;
        memorySize = 4096;
        vcpu = 4;
        #networks = [ "ngse-dedyn-io" ];
      };
    };

    networking.hostName = "ngse";
    networking.domain = "dedyn.io";
  };
}

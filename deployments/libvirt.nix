{
  ngse = { config, pkgs, ... }: rec
  {
    deployment = {
      targetEnv = "libvirtd";
      libvirtd = {
        headless = true;
        memorySize = 2048;
        vcpu = 2;
      };
    };
    networking.hostName = "ngse.dedyn.io";
  };
}

{
  ngse = { config, pkgs, ... }: rec
  {
    deployment.targetEnv = "libvirtd";
    networking.hostName = "ngse.dedyn.io";
  };
}

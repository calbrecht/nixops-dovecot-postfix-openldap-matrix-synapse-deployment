{
  description = "A nixops hetzner deployment flake";

  inputs = {
    nixpkgs = { url = github:NixOS/nixpkgs/master; };
  };

  outputs = flakes @ { self, nixpkgs }: {
    nixopsConfigurations.default = {
      inherit nixpkgs;

      defaults = {
        imports = [ (import /ws/hetzner/cx20/ngse.nix).ngse ];
      };

    } // (import /ws/hetzner/cx20/deployments/hetzner.nix flakes);
  };
}

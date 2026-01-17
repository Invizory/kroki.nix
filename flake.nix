{
  description = "NixOS module for Kroki";

  inputs = {
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
  };

  outputs =
    { quadlet-nix, ... }:
    {
      nixosModules.kroki = {
        imports = [
          quadlet-nix.nixosModules.quadlet
          ./nixos-module.nix
        ];
      };
    };
}

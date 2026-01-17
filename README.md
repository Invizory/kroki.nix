# Kroki for NixOS

[Kroki](https://kroki.io) provides a unified API to create various diagrams
from textual descriptions.

## Quick Start

### `flake.nix`

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
    kroki-nix = {
      url = "github:Invizory/kroki.nix";
      inputs.quadlet-nix.follows = "quadlet-nix";
    };
  };
  outputs =
    { nixpkgs, kroki-nix, ... }:
    {
      nixosConfigurations.machine = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          kroki-nix.nixosModules.kroki
        ];
      };
    };
}
```

### `configuration.nix`

```nix
{ config, ... }:
{
  # ...
  services.kroki = {
    enable = true;
    version = "0.27.0";
    listen.port = 80;
    features = {
      mermaid.enable = true;
      bpmn.enable = true;
      excalidraw.enable = true;
      diagramsnet.enable = true;
    };
  };
  networking.firewall.allowedTCPPorts = [ 80 ];
}
```

## Copyright

Copyright © 2026 Arthur Khashaev. See [license](LICENSE.txt) for details.

{
  description = "Flake to simplify self-hosting a mesh network with DERPER and FRP (residing on machine A), Headscale (residing on machine B)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ...  }@inputs: {
    nixosConfiguration = {
      
      upstreamEdge = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./modules/upstream-vps.nix ];
      };

      downstrreamNode = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./modules/downstream-local.nix ];
      };


    };
  
  };

}

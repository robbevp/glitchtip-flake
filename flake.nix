{
  description = "A wrapper around glitchtip";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs = { self, nixpkgs }:
    rec {
      nixosModules.glitchtip = import ./default.nix;
      nixosModule = nixosModules.glitchtip;
    };
}

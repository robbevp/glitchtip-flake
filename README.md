# Glitchtip flake

A flake to easily deploy [glitchtip](https://glitchtip.com) on nixos.

## How to use

If you have your system set up with flakes, you can add Glitchtip as a
service to your system flake:

```nix
{
  # add this flake as an input
  inputs.glitchtip = {
    url = "github:robbevp/glitchtip-flake";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, glitchtip }: {
    # change `yourhostname` to your actual hostname
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      # change to your system:
      system = "x86_64-linux";
      modules = [
        glitchtip.nixosModule

        # your configuration
        ./configuration.nix
      ];
    };
  };
}
```

Next, you can enable this service as if it is a normal NixOS service:

```nix
{
  services.glichtip = {
    enable = true;
    hostname = "glitchtip.example.com";
    defaultFromEmail = "info@example.com";
    environmentFile = "/var/lib/glitchtip/secret.env";
  };
}
```

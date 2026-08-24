{
  description = "nixpkg-overlay — keep bun at latest upstream release";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      overlays.default = import ./overlay.nix;

      # `nix build .#bun`  / `nix build .#packages.x86_64-linux.bun`
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          bun = pkgs.callPackage ./pkgs/bun/package.nix { };
          default = pkgs.callPackage ./pkgs/bun/package.nix { };
        }
      );

      # `nix run .#update-bun` 备用，实际更新走 scripts/update-bun.sh + CI
      apps = forAllSystems (system: {
        update-bun = {
          type = "app";
          program = "${self.packages.${system}.bun}/bin/bun";
        };
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}

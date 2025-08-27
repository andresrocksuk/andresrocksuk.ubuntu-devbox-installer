{
  description = "Basic Nix flake for WSL development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          hello = pkgs.hello;
          figlet = pkgs.figlet;
          
          # Create a combined package that includes both
          default = pkgs.buildEnv {
            name = "basic-wsl-tools";
            paths = with pkgs; [
              hello
              figlet
            ];
          };
        };

        # Development shell with the packages available
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            hello
            figlet
          ];
          
          shellHook = ''
            echo "🎉 Basic WSL tools loaded successfully!"
            echo "Available commands:"
            echo "  - hello: Hello world program"
            echo "  - figlet: ASCII art text generator"
            echo ""
            echo "Try: figlet 'Hello WSL!'"
          '';
        };

        # Apps for direct execution
        apps = {
          hello = flake-utils.lib.mkApp {
            drv = pkgs.hello;
          };
          figlet = flake-utils.lib.mkApp {
            drv = pkgs.figlet;
          };
          default = self.apps.${system}.hello;
        };
      });
}

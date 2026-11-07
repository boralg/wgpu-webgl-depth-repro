{
  description = "wgpu WebGL depth textureLoad repro";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rust-overlay, ... }:
    let
      inherit (nixpkgs) lib;

      perSystem =
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ rust-overlay.overlays.default ];
          };
          toolchain = pkgs.rust-bin.stable.latest.default.override {
            extensions = [ "rust-src" ];
            targets = [ "wasm32-unknown-unknown" ];
          };
          rustPlatform = pkgs.makeRustPlatform {
            cargo = toolchain;
            rustc = toolchain;
          };

          wasm-bindgen-cli = pkgs.wasm-bindgen-cli_0_2_130;
          gpuLibraryPath = lib.makeLibraryPath [
            pkgs.vulkan-loader
            pkgs.libglvnd
          ];

          web = rustPlatform.buildRustPackage {
            pname = "wgpu-webgl-depth-repro";
            version = "0.1.0";

            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./Cargo.toml
                ./Cargo.lock
                ./src
                ./web/index.html
              ];
            };

            cargoLock.lockFile = ./Cargo.lock;

            nativeBuildInputs = [ wasm-bindgen-cli ];

            doCheck = false;

            buildPhase = ''
              runHook preBuild
              cargo build --release --target wasm32-unknown-unknown
              wasm-bindgen \
                target/wasm32-unknown-unknown/release/wgpu-webgl-depth-repro.wasm \
                --out-dir pkg --out-name wgpu_webgl_depth_repro --web
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out
              cp web/index.html $out/
              cp -r pkg $out/
              runHook postInstall
            '';
          };

          native = rustPlatform.buildRustPackage {
            pname = "wgpu-webgl-depth-repro";
            version = "0.1.0";

            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./Cargo.toml
                ./Cargo.lock
                ./src
              ];
            };

            cargoLock.lockFile = ./Cargo.lock;
            doCheck = false;

            postFixup = lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
              patchelf --add-rpath ${gpuLibraryPath} $out/bin/wgpu-webgl-depth-repro
            '';
          };

          serve = pkgs.writeShellScript "serve" ''
            ${pkgs.python3}/bin/python3 -m http.server 8000 --directory ${web}
          '';
        in
        {
          packages = {
            default = web;
            wasm32-unknown-unknown = web;
            ${system} = native;
          };

          apps.default = {
            type = "app";
            program = "${serve}";
          };

          devShells.default = pkgs.mkShell {
            packages = [
              toolchain
              wasm-bindgen-cli
              pkgs.python3
            ];
            LD_LIBRARY_PATH = gpuLibraryPath;
          };
        };

      systems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ] perSystem;
    in
    {
      packages = lib.mapAttrs (_: s: s.packages) systems;
      apps = lib.mapAttrs (_: s: s.apps) systems;
      devShells = lib.mapAttrs (_: s: s.devShells) systems;
    };
}

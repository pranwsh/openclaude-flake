{
  description = "OpenClaude — open-source multi-model coding agent CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    let
      # Define the module once so it can be used for both Home Manager and NixOS
      openclaudeModule =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.programs.openclaude;
          yamlFormat = pkgs.formats.json { };
        in
        {
          options.programs.openclaude = {
            enable = lib.mkEnableOption "OpenClaude";

            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.system}.default;
              description = "The OpenClaude package to use.";
            };

            settings = lib.mkOption {
              type = lib.types.submodule {
                freeformType = yamlFormat.type;
                options = {
                  agentModels = lib.mkOption {
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        freeformType = yamlFormat.type;
                        options = {
                          base_url = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "Base URL for the model API.";
                          };
                          api_key = lib.mkOption {
                            type = lib.types.nullOr lib.types.str;
                            default = null;
                            description = "API key for the model.";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Configuration for different agents and their models.";
                  };

                  agentRouting = lib.mkOption {
                    type = lib.types.attrsOf lib.types.str;
                    default = { };
                    description = "Routing table for mapping agent types to specific models.";
                  };

                  theme = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Theme for the CLI (e.g., 'dark', 'light').";
                  };

                  mcpServers = lib.mkOption {
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        freeformType = yamlFormat.type;
                        options = {
                          command = lib.mkOption {
                            type = lib.types.str;
                            description = "The command to run the MCP server.";
                          };
                          args = lib.mkOption {
                            type = lib.types.listOf lib.types.str;
                            default = [ ];
                            description = "Arguments for the MCP server command.";
                          };
                          env = lib.mkOption {
                            type = lib.types.attrsOf lib.types.str;
                            default = { };
                            description = "Environment variables for the MCP server.";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Model Context Protocol (MCP) servers.";
                  };

                  env = lib.mkOption {
                    type = lib.types.attrsOf lib.types.str;
                    default = { };
                    description = "Environment variables to be included in the settings.";
                  };

                  dangerouslySkipPermissions = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "If true, skips confirmation prompts for tool execution.";
                  };

                  showCacheStats = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Displays token usage and caching efficiency.";
                  };

                  extendedThinking = lib.mkOption {
                    type = lib.types.nullOr lib.types.bool;
                    default = null;
                    description = "Enables/disables reasoning-heavy modes.";
                  };
                };
              };
              default = { };
              description = "Configuration for ~/.claude/settings.json.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ cfg.package ];
            home.file.".claude/settings.json".text = builtins.toJSON (
              lib.filterAttrs (n: v: v != null) cfg.settings
            );
          };
        };
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # ── Source ────────────────────────────────────────────────────────────
        # After cloning, run `nix build` once; the error message will print the
        # real hash — paste it here, then build succeeds and is cached forever.
        src = pkgs.fetchgit {
          url = "https://node.gitlawb.com/z6MkqDnb7Siv3Cwj7pGJq4T5EsUisECqR8KpnDLwcaZq5TPr/openclaude.git";
          hash = "sha256-4bWAtzDsU7CB2BYsnbHDxKn+mH6zJe8BlQubVFeCrLw=";
          # Uncomment if the repo uses submodules:
          # fetchSubmodules = true;
        };

        # ── Step 1: fetch bun dependencies (fixed-output derivation) ──────────
        # Fixed-output derivations (FODs) are the only derivations allowed
        # network access in Nix. We fetch node_modules here and reuse them in
        # the real build below, which runs fully sandboxed.
        #
        # To get the correct hash:
        #   1. Leave outputHash as lib.fakeHash (or the placeholder below)
        #   2. Run: nix build .#openclaude-deps
        #   3. Copy the hash from the error and paste it here
        nodeDeps = pkgs.stdenv.mkDerivation {
          name = "openclaude-node-deps";
          inherit src;

          nativeBuildInputs = [ pkgs.bun ];

          buildPhase = ''
            export HOME=$(mktemp -d)
            bun install --frozen-lockfile
          '';

          installPhase = ''
            cp -r node_modules $out
          '';

          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = "sha256-sAR4YiMNPNSZHKzoca90O50/fIlIZir0euZ4WaTPEWw=";

        };

        # ── Step 2: build OpenClaude (sandboxed, uses pre-fetched deps) ───────
        openclaude = pkgs.stdenv.mkDerivation {
          pname = "openclaude";
          version = "unstable-2026";
          inherit src;

          nativeBuildInputs = [
            pkgs.bun
            pkgs.nodejs
            pkgs.makeWrapper
            pkgs.ripgrep # openclaude requires `rg` on PATH at runtime
          ];

          buildPhase = ''
            export HOME=$(mktemp -d)

            # Bring in the pre-fetched node_modules (needs to be writable)
            cp -r ${nodeDeps} node_modules
            chmod -R u+w node_modules

            bun run build
          '';

          installPhase = ''
            mkdir -p $out/lib/openclaude $out/bin

            # Copy the built project
            cp -r . $out/lib/openclaude

            # Read the bin entry from package.json to find the CLI entrypoint.
            # Adjust the path below if `bun run build` puts the output elsewhere
            # (common locations: dist/index.js, dist/cli.js, build/index.js).
            local bin_entry=$(${pkgs.nodejs}/bin/node -e "
              const p = require('./package.json');
              const bins = p.bin;
              if (typeof bins === 'string') process.stdout.write(bins);
              else process.stdout.write(Object.values(bins)[0]);
            ")

            makeWrapper ${pkgs.nodejs}/bin/node $out/bin/openclaude \
              --add-flags "$out/lib/openclaude/$bin_entry" \
              --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.ripgrep ]}
          '';

          meta = with pkgs.lib; {
            description = "Open-source coding-agent CLI for OpenAI, Gemini, DeepSeek, Ollama, and 200+ models";
            homepage = "https://github.com/Gitlawb/openclaude";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

      in
      {
        # ── Packages ──────────────────────────────────────────────────────────
        packages = {
          default = openclaude;
          openclaude = openclaude;
          openclaude-deps = nodeDeps; # build this first to get the deps hash
        };

        # ── App (nix run) ─────────────────────────────────────────────────────
        apps.default = {
          type = "app";
          program = "${openclaude}/bin/openclaude";
        };

        # ── Dev shell ─────────────────────────────────────────────────────────
        # `nix develop` gives you bun + node + rg so you can hack on openclaude
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.bun
            pkgs.nodejs
            pkgs.ripgrep
            pkgs.git
          ];
          shellHook = ''
            echo "OpenClaude dev shell ready."
            echo "Run: bun install && bun run build && npm link"
          '';
        };
      }
    )
    // {
      # ── Modules ────────────────────────────────────────────────────────────
      homeManagerModules.default = openclaudeModule;
      homeManagerModules.openclaude = openclaudeModule;

      # Also provide a NixOS module (though Home Manager is preferred for CLI tools)
      nixosModules.default =
        { pkgs, ... }:
        {
          environment.systemPackages = [ self.packages.${pkgs.system}.default ];
        };
    };
}

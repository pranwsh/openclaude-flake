# openclaude-flake

A Nix flake that packages [OpenClaude](https://github.com/Gitlawb/openclaude) — the open-source multi-model coding agent CLI.

## Quick start

```bash
# Run without installing
nix run github:pranwsh/openclaude-flake

# Install into your profile
nix profile install github:pranwsh/openclaude-flake

# Drop into a dev shell (bun + node + ripgrep)
nix develop github:pranwsh/openclaude-flake
```


## Model configuration

OpenClaude routes different agents to different models. Edit `~/.claude/settings.json`:

```json
{
  "agentModels": {
    "deepseek-chat": {
      "base_url": "https://api.deepseek.com/v1",
      "api_key": "sk-your-key"
    },
    "gpt-4o": {
      "base_url": "https://api.openai.com/v1",
      "api_key": "sk-your-key"
    }
  },
  "agentRouting": {
    "Explore":     "deepseek-chat",
    "Plan":        "gpt-4o",
    "default":     "gpt-4o"
  }
}
```

To use a local Ollama model instead:

```bash
export CLAUDE_CODE_USE_OPENAI=1
export OPENAI_BASE_URL=http://localhost:11434/v1
export OPENAI_MODEL=qwen2.5-coder:7b
openclaude
```

## NixOS / Home Manager integration

Add to your flake inputs:

```nix
inputs.openclaude.url = "github:YOUR_USERNAME/openclaude-flake";
```

### Home Manager (Recommended)

Import the module and configure it:

```nix
{ inputs, pkgs, ... }: {
  imports = [ inputs.openclaude.homeManagerModules.default ];

  programs.openclaude = {
    enable = true;
    
    # Optional: override the package
    # package = inputs.openclaude.packages.${pkgs.system}.default;

    settings = {
      agentModels = {
        "deepseek-chat" = {
          base_url = "https://api.deepseek.com/v1";
          api_key = "sk-your-key";
        };
        "gpt-4o" = {
          base_url = "https://api.openai.com/v1";
          api_key = "sk-your-key";
        };
      };
      agentRouting = {
        "Explore" = "deepseek-chat";
        "Plan" = "gpt-4o";
        "default" = "gpt-4o";
      };
      # Example of other settings like theme
      theme = "dark";

      # Behavioral flags
      dangerouslySkipPermissions = false;
      showCacheStats = true;
      extendedThinking = true;

      # MCP (Model Context Protocol) Servers
      mcpServers = {
        sqlite = {
          command = "${pkgs.uv}/bin/uvx";
          args = [ "mcp-server-sqlite" "--db-path" "/path/to/your/db.sqlite" ];
        };
      };

      # Environment variables (can also be used for API keys)
      env = {
        "ANTHROPIC_API_KEY" = "sk-ant-...";
      };
    };
  };
}
```

### NixOS

If you just want the package available system-wide without configuration:

```nix
{ inputs, pkgs, ... }: {
  imports = [ inputs.openclaude.nixosModules.default ];
}
```

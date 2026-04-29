# openclaude-flake

A Nix flake that packages [OpenClaude](https://github.com/Gitlawb/openclaude) — the open-source multi-model coding agent CLI.

## Quick start

```bash
# Run without installing
nix run github:YOUR_USERNAME/openclaude-flake

# Install into your profile
nix profile install github:YOUR_USERNAME/openclaude-flake

# Drop into a dev shell (bun + node + ripgrep)
nix develop github:YOUR_USERNAME/openclaude-flake
```

## First-time setup (getting the hashes)

Nix requires content hashes for all fetched content. You need to fill in two
hashes in `flake.nix` before the build works.

### 1. Get the source hash

Replace the placeholder `src` hash with `lib.fakeHash`, then run:

```bash
nix build .#openclaude 2>&1 | grep "got:"
```

Paste the printed hash into the `src` block:

```nix
src = pkgs.fetchgit {
  url = "https://node.gitlawb.com/...";
  hash = "sha256-<hash from above>";
};
```

### 2. Get the bun deps hash

Build just the dependency derivation:

```bash
nix build .#openclaude-deps 2>&1 | grep "got:"
```

Paste the printed hash into `nodeDeps`:

```nix
outputHash = "sha256-<hash from above>";
```

### 3. Final build

```bash
nix build .#openclaude
./result/bin/openclaude --version
```

Commit and push — everyone else can now use your flake with no manual steps.

## Updating to a new version

1. Update the `rev` (or remove it to track HEAD) and clear the hashes back to the placeholder.
2. Repeat the two hash steps above.
3. Commit the updated `flake.nix` and `flake.lock`.

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

Then in your packages list:

```nix
environment.systemPackages = [
  inputs.openclaude.packages.${system}.default
];
```

# say-serif-rb

A minimal MCP stdio server that speaks text using macOS `say`.

Defaults: concurrency=1, dedupe=30s, hard timeout=300s.

[日本語版](README.md)

## Dependencies
- Ruby
- gem: `mcp` (Ruby SDK)

## Install Ruby 4.0.0 with rbenv (for first-time setup)
```bash
rbenv install 4.0.0
rbenv local 4.0.0
ruby -v
```
If `ruby -v` does not show `4.0.0`, your shell may be missing `eval "$(rbenv init - zsh)"`.

## Run (local)
```bash
ruby -S gem install mcp
ruby main.rb
```

## About executable permissions
When you `git clone` or `git pull`, the executable bit is usually preserved, but ZIP downloads or environment settings may drop it. If so, add execute permission locally.
```bash
chmod +x main.rb
```

## MCP config example
- Replace **/ABSOLUTE/PATH/TO/** with your actual path.
```json
{
  "mcpServers": {
    "say-serif-rb": {
      "command": "ruby",
      "args": ["/ABSOLUTE/PATH/TO/say-serif-rb/main.rb"]
    }
  }
}
```

## Codex config.toml example
- Replace **/ABSOLUTE/PATH/TO/** with your actual path.
```toml
[mcp_servers.say-serif-rb]
command = "ruby"
args = ["/ABSOLUTE/PATH/TO/say-serif-rb/main.rb"]
```

## Copilot (MCP) config example
- Replace **/ABSOLUTE/PATH/TO/** with your actual path.
```json
{
  "mcpServers": {
    "say-serif-rb": {
      "command": "ruby",
      "args": ["/ABSOLUTE/PATH/TO/say-serif-rb/main.rb"]
    }
  }
}
```

## AGENTS.md snippet (Codex)
```markdown
- Unless otherwise instructed, the agent should read the following using mcp_servers.say-serif-rb at speed=1.25x.
  - The agent's final response in natural language, excluding markdown, code, and paths
  - Any prompts asking the user to respond or approve an action
```

## Debug
If you run with environment variable `SAY_SERIF_RB_DEBUG=1`, logs are written to `tmp/boot.log`.

## License (dependencies)
- `mcp` gem: MIT
- `json-schema` gem: MIT

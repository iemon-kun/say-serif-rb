# say-serif-rb

macOSの`say`で読み上げる最小構成のMCP stdioサーバーです。

既定値: 同時実行=1、重複抑止=30秒、ハードタイムアウト=300秒。

## 依存
- Ruby
- gem: `mcp`（Ruby SDK）

## rbenvでRuby 4.0.0を入れる（未導入向け）
```bash
rbenv install 4.0.0
rbenv local 4.0.0
ruby -v
```
`ruby -v`で`4.0.0`が出ない場合は、`eval "$(rbenv init - zsh)"`がシェルに入っていない可能性があります。

## 起動（ローカル）
```bash
ruby -S gem install mcp
ruby main.rb
```

## MCP設定例
- **/ABSOLUTE/PATH/TO/**を実際のパスに書き換えます。
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

## Codex config.toml 例
- **/ABSOLUTE/PATH/TO/**を実際のパスに書き換えます。
```toml
[mcp_servers.say-serif-rb]
command = "ruby"
args = ["/ABSOLUTE/PATH/TO/say-serif-rb/main.rb"]
```

## Copilot（MCP）設定例
- **/ABSOLUTE/PATH/TO/**を実際のパスに書き換えます。
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

## AGENTS.md 記述例(Codex)
```markdown
- エージェントは特別な指示がない限り、基本的には下記の情報をmcp_servers.say-serif-rbを使いspeed=1.25xで読み上げる。
  - マークダウン、コード内容、パスなどを除いた自然言語で構成されるエージェント自身の最終返答
  - ユーザーに返答や実行の許可を求める場合の呼びかけ
```

## デバッグ
環境変数`SAY_SERIF_RB_DEBUG=1`で起動すると、`tmp/boot.log`にログを出します。

## ライセンス（依存）
- `mcp` gem: MIT
- `json-schema` gem: MIT

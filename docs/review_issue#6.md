# 実装計画レビュー結果: development 環境でパスキーの動作が確認できる (Issue #6)

対象: `docs/design_issue#6.md`

## 2回目レビュー: OK（軽微な指摘2点あり）

修正後の設計書（原因を「`current_user.id.to_s` を `user.id` に渡している」に
修正し、`webauthn_id` カラムの追加・自動生成・コントローラー修正という方針に
変更したもの）を確認した。

### 良い点

- 原因分析が正確: 1回目レビューの検証結果と完全に一致する結論になっている
- 修正方針（`webauthn_id` カラム追加 + `WebAuthn.generate_user_id` で自動生成
  + コントローラーで参照）も妥当
- `Webauthn::AuthenticationsController` は変更不要という判断も正しい
  （discoverable credential 方式のため `user.id` を扱わない）

### 指摘1（要対応）: テストフィクスチャの更新漏れ

`test/fixtures/users.yml` に `webauthn_id` が無いままだった。フィクスチャは
ActiveRecord のコールバック（`before_create`）を経由せず直接 INSERT される
ため、マイグレーションで `webauthn_id` を `NOT NULL` にすると、既存のテストが
フィクスチャ読み込み時点で失敗する。

`password_digest` を `<%= BCrypt::Password.create(...) %>` で対応したのと
同様に、以下のような対応が必要：

```yaml
one:
  username: alice
  password_digest: <%= BCrypt::Password.create("password123") %>
  webauthn_id: <%= WebAuthn.generate_user_id %>
```

「影響範囲」に `test/fixtures/users.yml` を追加しておくべき。

### 指摘2（軽微・任意）: バックフィルの具体的な手順が未記載

「既存ユーザーへのバックフィルもマイグレーション内で対応する」とあるが、
`NOT NULL` 制約を先に付けると既存行がある場合に失敗するため、実装時は
「①nullable でカラム追加 → ②既存行をバックフィル → ③`change_column_null`
で `NOT NULL` に変更」という順序を踏む必要がある。今回は開発中の sandbox
アプリで実データはほぼ無い想定なので実害は小さいが、一言触れておくとより
明確。

### 2回目レビューの結論

いずれも実装時にすぐ気づける軽微な内容で、根本方針は正しいため、この設計書
のまま実装に進めて問題ない。

---

## 1回目レビュー: NG（原因分析に誤りがあり、再検討が必要）

`webauthn` gem および `@github/webauthn-json` のソースコードを実際に確認し、
Node.js で該当関数を動かして検証した結果、設計書の原因分析には事実と異なる
箇所が複数あった。

## 検証1: 「原因1: displayName の欠落」は誤り

設計書は「`user.displayName` が未指定でエラーの有力候補」としているが、
`webauthn` gem の `UserEntity` を確認すると displayName は自動補完される。

```ruby
# webauthn-3.4.3/lib/webauthn/public_key_credential/user_entity.rb
def initialize(id:, display_name: nil, **keyword_arguments)
  super(**keyword_arguments)
  @id = id
  @display_name = display_name || name  # ← name から自動補完される
end
```

`display_name` を渡さなくても `name` の値がそのまま使われる。実際に現在のコード
でオプションを生成して確認したところ：

```json
{"user":{"name":"alice","id":"1","displayName":"alice"}}
```

`displayName` は入っている。この原因分析は成立しない。

## 検証2: 実際の原因は `user.id` に生の DB ID を使っていること

現在のコード（`Webauthn::RegistrationsController#options`）:

```ruby
user: { id: current_user.id.to_s, name: current_user.username }
```

WebAuthn仕様では `user.id` はブラウザ側で `atob()` を使って base64url から
バイト列にデコードされる。ここに渡されている値は `"1"`, `"2"` のような
ただの10進数の文字列であり、base64url としては不正な形式。

`@github/webauthn-json` の実際のデコード関数（`base64urlToBuffer`）を
Node.js で動かして確認した結果：

```
FAIL input="1" -> InvalidCharacterError: The string to be decoded is not correctly encoded.
FAIL input="alice" -> InvalidCharacterError: The string to be decoded is not correctly encoded.
```

Issue #6 に書かれているエラーメッセージと完全に一致する。これが真の原因。

## 検証3: 「原因3: credential ID の二重エンコード」も裏付けなし

`exclude:` に渡された ID は `as_public_key_descriptors` でそのままラップ
されるだけで、再エンコードは行われない（gem のソースで確認済み）。

```ruby
# webauthn-3.4.3/lib/webauthn/public_key_credential/options.rb
def as_public_key_descriptors(ids)
  Array(ids).map { |id| { type: TYPE_PUBLIC_KEY, id: id } }
end
```

二重エンコードの心配は不要。

## 検証4: 「エンコーディング設定の明示」は不要

`WebAuthn::Encoder::STANDARD_ENCODING` は既にデフォルトで `:base64url`。

```ruby
# webauthn-3.4.3/lib/webauthn/encoder.rb
STANDARD_ENCODING = :base64url
```

明示的な設定は冗長で不要な変更。

## 推奨する修正方針

原因は一点に絞れる。**`user.id` に、ランダムなバイト列を base64url エンコード
した専用の識別子（WebAuthn user handle）を使うこと。** gem 自体に生成用
ヘルパーが用意されている。

```ruby
WebAuthn.generate_user_id
# => configuration.encoder.encode(SecureRandom.random_bytes(64))
```

修正イメージ:

1. `users` テーブルに `webauthn_id` (string, NOT NULL, UNIQUE, INDEX) を
   追加するマイグレーション
2. `User` モデルで `before_create { self.webauthn_id ||= WebAuthn.generate_user_id }`
   のように自動生成
3. `Webauthn::RegistrationsController#options` で
   `id: current_user.id.to_s` を `id: current_user.webauthn_id` に変更

`Webauthn::AuthenticationsController` 側（ログイン）は `user.id` を扱わない
discoverable credential 方式なので、今回の修正範囲には含める必要はない
（設計書は影響範囲に含めているが、根拠がない）。

## 補足

このまま実装に進めると、設計書の「Step 1: サーバーレスポンスの確認」を
無駄に繰り返すことになる。GitHub Copilot に上記の検証結果を元にした
再検討を依頼するのがよい。

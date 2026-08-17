# 実装計画: development 環境でパスキーの動作が確認できる (Issue #6)

## 問題の概要

JavaScript コンソールに以下のエラーが発生する：
```
InvalidCharacterError: Failed to execute 'atob' on 'Window': The string to be decoded is not correctly encoded.
```

## 原因

`Webauthn::RegistrationsController#options` で `user.id` に `current_user.id.to_s`（"1", "2" 等の10進数文字列）を渡している。

`@github/webauthn-json` の `base64urlToBuffer()` はこの値を base64url としてデコードしようとするが、"1" や "2" は有効な base64url 文字列ではないため `atob()` が失敗する。

WebAuthn 仕様では `user.id` はランダムなバイト列（user handle）を base64url エンコードしたものであるべき。

## 修正方針

### Step 1: マイグレーション追加

`users` テーブルに `webauthn_id` カラム（string, NOT NULL, UNIQUE）を追加する。

### Step 2: User モデル修正

`before_create` で `webauthn_id` を自動生成する：

```ruby
before_create { self.webauthn_id ||= WebAuthn.generate_user_id }
```

既存ユーザーへのバックフィルもマイグレーション内で対応する。

### Step 3: コントローラー修正

`app/controllers/webauthn/registrations_controller.rb` の `options` アクションで：

```ruby
# Before
user: { id: current_user.id.to_s, name: current_user.username }

# After
user: { id: current_user.webauthn_id, name: current_user.username }
```

`Webauthn::AuthenticationsController` は discoverable credential 方式で `user.id` を扱わないため変更不要。

### Step 4: 動作確認

1. ブラウザで `/signup` → パスキー登録のフローを実行
2. `/login` → パスキー認証のフローを実行
3. JavaScript コンソールにエラーが出ないことを確認

## 影響範囲

- `db/migrate/` — webauthn_id カラム追加
- `app/models/user.rb` — webauthn_id 自動生成
- `app/controllers/webauthn/registrations_controller.rb` — user.id の修正

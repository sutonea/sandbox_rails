# 実装計画: ユーザー認証ができるようにする (Issue #4)

## 概要

パスキー（WebAuthn）をデフォルトとし、パスワードをフォールバックとするユーザー認証機能を、Rails 標準機能ベースで自前実装する。

## 要件整理

- ユーザーが新規登録できる（ユーザーIDは任意の文字列＝ユーザー名）
- デフォルトでパスキー（WebAuthn）を用いる
- パスキー未対応時のフォールバックとしてパスワード認証を提供
- ユーザーがパスキーでログインできる

## 技術選定

| 項目 | 選定 | 理由 |
|------|------|------|
| 認証基盤 | Rails 標準 (`has_secure_password`) | シンプル・学習向き |
| WebAuthn | `webauthn` gem | Ruby 向け WebAuthn ライブラリの標準 |
| セッション管理 | Rails 標準セッション | 追加依存なし |
| フロントエンド | Stimulus + importmap | 既存構成に合わせる |

## データベース設計

### users テーブル

| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | bigint | PK | 内部ID |
| username | string | NOT NULL, UNIQUE, INDEX | ユーザー名（ログイン識別子） |
| password_digest | string | NOT NULL | bcrypt ハッシュ |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

- username のバリデーション: 3〜32文字、英数字・アンダースコア・ハイフンのみ

### webauthn_credentials テーブル

| カラム | 型 | 制約 | 説明 |
|--------|------|------|------|
| id | bigint | PK | 内部ID |
| user_id | bigint | NOT NULL, FK(users), INDEX | |
| external_id | string | NOT NULL, UNIQUE | credential ID (Base64URL) |
| public_key | string | NOT NULL | 公開鍵 |
| sign_count | bigint | NOT NULL, DEFAULT 0 | リプレイ攻撃防止用カウンタ |
| nickname | string | | 鍵の表示名（例: "MacBook Pro"） |
| created_at | datetime | NOT NULL | |
| updated_at | datetime | NOT NULL | |

## 画面設計

| パス | 用途 |
|------|------|
| GET /signup | 新規登録フォーム |
| POST /signup | ユーザー作成 |
| GET /login | ログインフォーム（パスキー優先 + パスワードフォールバック） |
| POST /login | パスワードログイン |
| DELETE /logout | ログアウト |
| POST /webauthn/registration/options | パスキー登録オプション取得 (JSON) |
| POST /webauthn/registration | パスキー登録完了 (JSON) |
| POST /webauthn/authentication/options | パスキー認証オプション取得 (JSON) |
| POST /webauthn/authentication | パスキー認証完了 (JSON) |

## 実装ステップ

### Step 1: 基盤セットアップ

1. `bcrypt` gem のコメント解除（Gemfile）
2. `webauthn` gem の追加
3. `bundle install`

### Step 2: User モデルとマイグレーション

1. User モデル作成（`has_secure_password`）
2. username のバリデーション追加
3. マイグレーション実行

### Step 3: セッション管理の基盤

1. `ApplicationController` に `current_user`、`logged_in?`、`require_login` ヘルパー追加
2. `SessionsController` 作成（パスワードログイン/ログアウト）
3. `RegistrationsController` 作成（新規登録）

### Step 4: パスキー（WebAuthn）対応

1. `WebauthnCredential` モデル作成
2. `WebauthnController` 作成（登録・認証の options/verify エンドポイント）
3. WebAuthn の `relying_party` 設定（イニシャライザ）

### Step 5: フロントエンド

1. `@github/webauthn-json` を importmap に追加
2. パスキー登録用 Stimulus コントローラー
3. ログイン画面でのパスキー認証フロー（Conditional UI 対応）

### Step 6: ビュー

1. 新規登録画面（username + password + パスキー登録ボタン）
2. ログイン画面（パスキー自動検出 + パスワードフォールバック）
3. ログイン後のトップページ（ログアウトボタン）

## セキュリティ考慮事項

- CSRF 対策: Rails 標準の `protect_from_forgery` を利用
- パスワード: bcrypt によるハッシュ化（`has_secure_password`）
- WebAuthn: `sign_count` 検証によるリプレイ攻撃防止
- セッション固定攻撃対策: ログイン時に `reset_session`

## テスト方針

- モデルテスト: User バリデーション、WebauthnCredential の関連
- コントローラーテスト: 登録・ログイン・ログアウトの正常系/異常系
- システムテスト: パスキーは実ブラウザでの手動確認（WebAuthn のモック困難なため）

#!/usr/bin/env python3
"""Register or remove the Antigravity (AGY) provider in CC Switch's SQLite database."""

import argparse
import json
import os
import sqlite3
import sys
import time

PROVIDER_ID = "antigravity-agy"
APP_TYPE = "codex"
PROVIDER_NAME = "Antigravity (AGY)"


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage Antigravity (AGY) provider in CC Switch.")
    parser.add_argument(
        "--db",
        default=os.path.expanduser("~/.cc-switch/cc-switch.db"),
        help="Path to cc-switch.db (default: ~/.cc-switch/cc-switch.db)",
    )
    parser.add_argument(
        "--base-url",
        default=os.environ.get("AGY_PROXY_BASE_URL", "http://127.0.0.1:8317/v1"),
        help="Local CLIProxyAPI endpoint URL",
    )
    parser.add_argument(
        "--api-key",
        default=os.environ.get("AGY_PROXY_API_KEY", "sk-agy-local"),
        help="Local CLIProxyAPI client key",
    )
    parser.add_argument(
        "--default-model",
        default=os.environ.get("AGY_MODEL", "gemini-4-argon"),
        help="Default model ID for Codex",
    )
    parser.add_argument(
        "--remove",
        action="store_true",
        help="Remove the Antigravity (AGY) provider from CC Switch",
    )
    args = parser.parse_args()

    if not os.path.exists(args.db):
        print(f"[skip] CC Switch database not found at {args.db}", file=sys.stderr)
        return 0

    conn = sqlite3.connect(args.db)
    cur = conn.cursor()

    if args.remove:
        cur.execute("DELETE FROM provider_endpoints WHERE provider_id = ? AND app_type = ?", (PROVIDER_ID, APP_TYPE))
        cur.execute("DELETE FROM providers WHERE id = ? AND app_type = ?", (PROVIDER_ID, APP_TYPE))
        conn.commit()
        conn.close()
        print(f"Removed '{PROVIDER_NAME}' ({PROVIDER_ID}) from {args.db}")
        return 0

    settings_config = {
        "auth": {"OPENAI_API_KEY": args.api_key},
        "config": (
            'model_provider = "custom"\n'
            f'model = "{args.default_model}"\n'
            "disable_response_storage = true\n\n"
            "[model_providers]\n"
            "[model_providers.custom]\n"
            'name = "antigravity"\n'
            f'base_url = "{args.base_url}"\n'
            'wire_api = "responses"\n'
            f'experimental_bearer_token = "{args.api_key}"\n'
            "requires_openai_auth = false\n"
        ),
        "modelCatalog": {
            "models": [
                {"model": "gemini-4-argon", "displayName": "Gemini 4 Argon", "contextWindow": 1000000},
                {"model": "gemini-3.8-flash", "displayName": "Gemini 3.8 Flash", "contextWindow": 1000000},
                {"model": "claude-sonnet-4-6", "displayName": "Claude Sonnet 4.6", "contextWindow": 200000},
                {"model": "claude-opus-4-6", "displayName": "Claude Opus 4.6", "contextWindow": 200000},
                {"model": "gpt-oss-120b", "displayName": "GPT-OSS 120B", "contextWindow": 128000},
                {"model": "gemini-3-flash", "displayName": "Gemini 3 Flash", "contextWindow": 1000000},
                {"model": "gemini-3.5-flash-lite", "displayName": "Gemini 3.5 Flash Lite", "contextWindow": 1000000},
            ]
        },
    }
    meta = {
        "commonConfigEnabled": True,
        "endpointAutoSelect": True,
        "apiFormat": "openai_responses",
        "codexChatReasoning": {
            "supportsThinking": True,
            "supportsEffort": True,
            "thinkingParam": "thinking",
            "effortParam": "effort",
            "outputFormat": "reasoning_content",
        },
    }
    now_ms = int(time.time() * 1000)

    cur.execute(
        """
        INSERT OR REPLACE INTO providers (
            id, app_type, name, settings_config, website_url, category,
            created_at, sort_index, notes, icon, icon_color, meta,
            is_current, in_failover_queue, cost_multiplier, provider_type
        ) VALUES (
            ?, ?, ?, ?, ?, ?,
            ?, ?, ?, ?, ?, ?,
            COALESCE((SELECT is_current FROM providers WHERE id = ? AND app_type = ?), 0),
            0, '1.0', ?
        )
        """,
        (
            PROVIDER_ID,
            APP_TYPE,
            PROVIDER_NAME,
            json.dumps(settings_config, ensure_ascii=False),
            "https://antigravity.google",
            "custom",
            now_ms,
            5,
            f"Local Antigravity OAuth proxy via CLIProxyAPI ({args.base_url})",
            "gemini",
            "#4285F4",
            json.dumps(meta, ensure_ascii=False),
            PROVIDER_ID,
            APP_TYPE,
            PROVIDER_ID,
        ),
    )

    cur.execute(
        "DELETE FROM provider_endpoints WHERE provider_id = ? AND app_type = ?",
        (PROVIDER_ID, APP_TYPE),
    )
    cur.execute(
        "INSERT INTO provider_endpoints (provider_id, app_type, url, added_at) VALUES (?, ?, ?, ?)",
        (PROVIDER_ID, APP_TYPE, args.base_url, now_ms),
    )

    conn.commit()
    conn.close()
    print(f"Registered '{PROVIDER_NAME}' ({args.base_url}) into CC Switch ({args.db}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

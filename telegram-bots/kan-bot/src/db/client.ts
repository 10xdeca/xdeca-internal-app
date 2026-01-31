import Database from "better-sqlite3";
import { drizzle } from "drizzle-orm/better-sqlite3";
import { mkdirSync } from "fs";
import { dirname } from "path";
import * as schema from "./schema.js";

const dbPath = process.env.DATABASE_PATH || "./data/kan-bot.db";

// Ensure directory exists
mkdirSync(dirname(dbPath), { recursive: true });

const sqlite = new Database(dbPath);
export const db = drizzle(sqlite, { schema });

// Initialize tables
sqlite.exec(`
  CREATE TABLE IF NOT EXISTS telegram_workspace_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    telegram_chat_id INTEGER NOT NULL UNIQUE,
    workspace_public_id TEXT NOT NULL,
    workspace_name TEXT NOT NULL,
    created_at INTEGER NOT NULL DEFAULT (unixepoch()),
    created_by_telegram_user_id INTEGER NOT NULL
  );

  CREATE TABLE IF NOT EXISTS telegram_user_links (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    telegram_user_id INTEGER NOT NULL UNIQUE,
    telegram_username TEXT,
    kan_user_email TEXT NOT NULL,
    kan_api_key TEXT NOT NULL,
    workspace_member_public_id TEXT,
    created_at INTEGER NOT NULL DEFAULT (unixepoch())
  );

  CREATE TABLE IF NOT EXISTS telegram_reminders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    card_public_id TEXT NOT NULL,
    telegram_chat_id INTEGER NOT NULL,
    reminder_type TEXT NOT NULL DEFAULT 'overdue',
    last_reminder_at INTEGER NOT NULL
  );

  CREATE INDEX IF NOT EXISTS idx_reminders_card_chat_type
    ON telegram_reminders(card_public_id, telegram_chat_id, reminder_type);
`);

// Migration: Add reminder_type column to existing databases
try {
  sqlite.exec(`ALTER TABLE telegram_reminders ADD COLUMN reminder_type TEXT NOT NULL DEFAULT 'overdue'`);
  console.log("Migration: Added reminder_type column to telegram_reminders");
} catch {
  // Column already exists, ignore
}

export { schema };

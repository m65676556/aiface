const { sql } = require('@vercel/postgres');

module.exports = async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');

  try {
    await sql`
      CREATE TABLE IF NOT EXISTS dating_profiles (
        device_id           TEXT PRIMARY KEY,
        photo_base64        TEXT,
        personality_summary TEXT,
        traits              TEXT,
        interests           TEXT,
        communication_style TEXT,
        values_text         TEXT,
        appearance_tags     TEXT,
        appearance_desc     TEXT,
        ideal_partner       TEXT,
        created_at          TIMESTAMPTZ DEFAULT NOW(),
        updated_at          TIMESTAMPTZ DEFAULT NOW()
      )
    `;

    await sql`
      CREATE TABLE IF NOT EXISTS chat_messages (
        id         TEXT PRIMARY KEY,
        from_id    TEXT NOT NULL,
        to_id      TEXT NOT NULL,
        content    TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    `;

    await sql`
      CREATE INDEX IF NOT EXISTS idx_chat_messages_pair
        ON chat_messages (from_id, to_id, created_at)
    `;

    res.status(200).json({ ok: true, message: 'Tables created successfully' });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message });
  }
}

import { sql } from '@vercel/postgres';
import { randomUUID } from 'crypto';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'POST') {
    const { from_id, to_id, content } = req.body;
    if (!from_id || !to_id || !content) {
      return res.status(400).json({ error: 'from_id, to_id and content are required' });
    }

    try {
      const id = randomUUID();
      await sql`
        INSERT INTO chat_messages (id, from_id, to_id, content)
        VALUES (${id}, ${from_id}, ${to_id}, ${content})
      `;
      return res.status(200).json({ ok: true, id });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  if (req.method === 'GET') {
    const { from_id, to_id, after } = req.query;
    if (!from_id || !to_id) {
      return res.status(400).json({ error: 'from_id and to_id are required' });
    }

    try {
      const afterTime = after ? new Date(after) : new Date(0);

      const { rows } = await sql`
        SELECT id, from_id, to_id, content, created_at
        FROM chat_messages
        WHERE (
          (from_id = ${from_id} AND to_id = ${to_id})
          OR
          (from_id = ${to_id} AND to_id = ${from_id})
        )
        AND created_at > ${afterTime.toISOString()}
        ORDER BY created_at ASC
      `;
      return res.status(200).json(rows);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}

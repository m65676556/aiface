import { sql } from '@vercel/postgres';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { device_id } = req.query;
  if (!device_id) {
    return res.status(400).json({ error: 'device_id is required' });
  }

  try {
    const { rows } = await sql`
      SELECT device_id, personality_summary, traits, interests,
             communication_style, values_text, appearance_tags,
             appearance_desc, ideal_partner, photo_base64, updated_at
      FROM dating_profiles
      WHERE device_id != ${device_id}
      ORDER BY updated_at DESC
      LIMIT 20
    `;
    return res.status(200).json(rows);
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
}

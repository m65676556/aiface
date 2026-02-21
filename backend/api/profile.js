import { sql } from '@vercel/postgres';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method === 'POST') {
    const {
      device_id,
      photo_base64,
      personality_summary,
      traits,
      interests,
      communication_style,
      values_text,
      appearance_tags,
      appearance_desc,
      ideal_partner,
    } = req.body;

    if (!device_id) {
      return res.status(400).json({ error: 'device_id is required' });
    }

    try {
      await sql`
        INSERT INTO dating_profiles (
          device_id, photo_base64, personality_summary, traits, interests,
          communication_style, values_text, appearance_tags, appearance_desc,
          ideal_partner, updated_at
        ) VALUES (
          ${device_id}, ${photo_base64 ?? null}, ${personality_summary ?? null},
          ${traits ?? null}, ${interests ?? null}, ${communication_style ?? null},
          ${values_text ?? null}, ${appearance_tags ?? null}, ${appearance_desc ?? null},
          ${ideal_partner ?? null}, NOW()
        )
        ON CONFLICT (device_id) DO UPDATE SET
          photo_base64        = EXCLUDED.photo_base64,
          personality_summary = EXCLUDED.personality_summary,
          traits              = EXCLUDED.traits,
          interests           = EXCLUDED.interests,
          communication_style = EXCLUDED.communication_style,
          values_text         = EXCLUDED.values_text,
          appearance_tags     = EXCLUDED.appearance_tags,
          appearance_desc     = EXCLUDED.appearance_desc,
          ideal_partner       = EXCLUDED.ideal_partner,
          updated_at          = NOW()
      `;

      return res.status(200).json({ ok: true });
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  if (req.method === 'GET') {
    const { device_id } = req.query;
    if (!device_id) {
      return res.status(400).json({ error: 'device_id is required' });
    }

    try {
      const { rows } = await sql`
        SELECT * FROM dating_profiles WHERE device_id = ${device_id}
      `;
      if (rows.length === 0) {
        return res.status(404).json({ error: 'Profile not found' });
      }
      return res.status(200).json(rows[0]);
    } catch (err) {
      return res.status(500).json({ error: err.message });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}

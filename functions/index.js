const {onRequest} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Se setea una sola vez con:
//   firebase functions:secrets:set GROQ_API_KEY
// Nunca se pisa desde el código ni se loguea.
const GROQ_API_KEY = defineSecret('GROQ_API_KEY');

const TEXT_MODEL = 'llama-3.3-70b-versatile';
const VISION_MODEL = 'meta-llama/llama-4-scout-17b-16e-instruct';
const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DAY_MS = 24 * 60 * 60 * 1000;

// ── Chequea y consume una unidad del límite diario del usuario ──────
// Medible como "cantidad de llamadas a la IA por día" (no tokens): es lo
// más simple de explicar y configurar desde el panel de admin, y alcanza
// para controlar costo, ya que cada llamada tiene un tope de max_tokens
// fijo en el backend (no lo elige el cliente).
async function checkAndConsumeUsage(username) {
  const normalized = username.trim().toLowerCase();
  const userRef = db.collection('users').doc(normalized);

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) {
      return {ok: false, code: 404, error: 'user_not_found', message: 'Usuario no encontrado.'};
    }

    const data = snap.data();
    if (data.isActive === false) {
      return {ok: false, code: 403, error: 'user_inactive', message: 'Tu cuenta está deshabilitada.'};
    }

    const limit = typeof data.aiUsageLimit === 'number' ? data.aiUsageLimit : 0; // 0 = sin límite
    const now = Date.now();
    const storedResetAt = data.aiUsageResetAt;
    const resetAtMs = storedResetAt && typeof storedResetAt.toMillis === 'function'
      ? storedResetAt.toMillis()
      : 0;

    let count = typeof data.aiUsageCount === 'number' ? data.aiUsageCount : 0;
    let newResetAtMs = resetAtMs;

    if (!resetAtMs || now >= resetAtMs) {
      count = 0;
      newResetAtMs = now + DAY_MS;
    }

    if (limit > 0 && count >= limit) {
      return {
        ok: false,
        code: 429,
        error: 'usage_limit_exceeded',
        message: 'Alcanzaste el límite diario de uso de IA. Probá de nuevo mañana.',
      };
    }

    tx.update(userRef, {
      aiUsageCount: count + 1,
      aiUsageResetAt: admin.firestore.Timestamp.fromMillis(newResetAtMs),
    });

    return {ok: true, userRef};
  });
}

// Si Groq falla después de haber consumido la cuota, se la devolvemos al
// usuario (best-effort: si esto falla no rompe la respuesta principal).
async function refundUsage(userRef) {
  try {
    await userRef.update({
      aiUsageCount: admin.firestore.FieldValue.increment(-1),
    });
  } catch (e) {
    logger.warn('refund_failed', e);
  }
}

exports.aiProxy = onRequest(
  {secrets: [GROQ_API_KEY], cors: true, region: 'us-central1', timeoutSeconds: 60},
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).json({error: 'method_not_allowed', message: 'Método no permitido.'});
      return;
    }

    // NOTA: esta función sigue sin desplegarse (plan Spark, sin Blaze) — este
    // cambio es solo por consistencia con firestore.rules (misma derivación
    // de username que myUsername()), no tiene efecto en runtime todavía.
    const authHeader = req.headers.authorization || '';
    const idToken = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
    if (!idToken) {
      res.status(401).json({error: 'unauthenticated', message: 'Falta token de autenticación.'});
      return;
    }

    let username;
    try {
      const decoded = await admin.auth().verifyIdToken(idToken);
      username = (decoded.email || '').split('@')[0];
      if (!username) throw new Error('token sin email');
    } catch (e) {
      logger.warn('invalid_id_token', e);
      res.status(401).json({error: 'unauthenticated', message: 'Token inválido o expirado.'});
      return;
    }

    const {messages, kind, temperature, maxTokens} = req.body || {};

    if (!Array.isArray(messages) || messages.length === 0) {
      res.status(400).json({error: 'invalid_request', message: 'Falta messages.'});
      return;
    }

    let usage;
    try {
      usage = await checkAndConsumeUsage(username);
    } catch (e) {
      logger.error('usage_check_failed', e);
      res.status(500).json({error: 'internal_error', message: 'Error interno verificando el uso.'});
      return;
    }

    if (!usage.ok) {
      res.status(usage.code).json({error: usage.error, message: usage.message});
      return;
    }

    const model = kind === 'vision' ? VISION_MODEL : TEXT_MODEL;
    const cappedMaxTokens = Math.min(typeof maxTokens === 'number' ? maxTokens : 1024, 4096);

    try {
      const groqRes = await fetch(GROQ_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${GROQ_API_KEY.value()}`,
        },
        body: JSON.stringify({
          model,
          messages,
          temperature: typeof temperature === 'number' ? temperature : 0.3,
          max_tokens: cappedMaxTokens,
        }),
      });

      const text = await groqRes.text();

      if (groqRes.status === 401 || groqRes.status === 403) {
        logger.error('groq_auth_error', {status: groqRes.status});
        await refundUsage(usage.userRef);
        res.status(502).json({error: 'groq_auth_error', message: 'La IA no está disponible en este momento. Avisá al administrador.'});
        return;
      }
      if (!groqRes.ok) {
        logger.error('groq_error', {status: groqRes.status, body: text});
        await refundUsage(usage.userRef);
        res.status(502).json({error: 'groq_error', message: 'Error consultando el servicio de IA.'});
        return;
      }

      const json = JSON.parse(text);
      const content = json.choices?.[0]?.message?.content ?? '';
      res.status(200).json({content});
    } catch (e) {
      logger.error('groq_call_failed', e);
      await refundUsage(usage.userRef);
      res.status(500).json({error: 'internal_error', message: 'Error interno llamando a la IA.'});
    }
  }
);

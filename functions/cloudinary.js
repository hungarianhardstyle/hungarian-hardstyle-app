const crypto = require('crypto');

function cloudinarySignature(params, apiSecret) {
  const payload = Object.keys(params).sort().map((key) => `${key}=${params[key]}`).join('&');
  return crypto.createHash('sha1').update(`${payload}${apiSecret}`).digest('hex');
}

function selectOwnedCloudinaryAssets(uid, assets) {
  const owned = [];
  let manualCleanupRequired = false;
  for (const asset of assets) {
    if (asset?.ownerUid !== uid) continue;
    if (typeof asset.publicId === 'string' && asset.publicId.trim()) {
      owned.push({ publicId: asset.publicId.trim(), secureUrl: asset.secureUrl || '' });
    } else if (typeof asset.secureUrl === 'string' && asset.secureUrl.includes('res.cloudinary.com/')) {
      manualCleanupRequired = true;
    }
  }
  return { assets: owned, manualCleanupRequired };
}

async function destroyCloudinaryAsset({ cloudName, apiKey, apiSecret, publicId, fetchImpl = fetch, now = Date.now }) {
  if (!publicId) return { status: 'manual_cleanup_required' };
  if (!cloudName || !apiKey || !apiSecret) throw new Error('cloudinary-secret-not-configured');
  const params = { invalidate: 'true', public_id: publicId, timestamp: Math.floor(now() / 1000) };
  const body = new URLSearchParams({ ...params, api_key: apiKey, signature: cloudinarySignature(params, apiSecret) });
  const response = await fetchImpl(`https://api.cloudinary.com/v1_1/${cloudName}/image/destroy`, {
    method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body,
  });
  const result = await response.json().catch(() => ({}));
  if (!response.ok || !['ok', 'not found'].includes(result.result)) {
    throw cloudinaryFailure('cloudinary-delete-temporary-failure', response, result, 'result');
  }
  return { status: 'deleted' };
}

/**
 * A Cloudinary-hiba diagnosztizalhato formaban.
 *
 * MIERT: korabban a hivas csak annyit mondott, hogy „cloudinary-list-temporary-failure",
 * igy a naplobol NEM derult ki, hogy 401 (rossz kulcs), 420/429 (rate limit) vagy
 * eppen valasz-alak volt a baj — a takaritas pedig orokre „fuggoben" maradt.
 * Mostantól a HTTP-statusz es a Cloudinary uzenete is benne van.
 */
function cloudinaryFailure(code, response, result, expectField) {
  const status = response?.status ?? 0;
  const message = String(result?.error?.message || '').trim();
  const error = new Error(
    `${code} status=${status}${message ? ` message=${message}` : ''}` +
      (expectField && result && !(expectField in result) ? ` hianyzik=${expectField}` : ''),
  );
  error.code = `${code}:${status}`;
  error.httpStatus = status;
  return error;
}

async function listOwnedCloudinaryAssets({ cloudName, apiKey, apiSecret, uid, fetchImpl = fetch }) {
  if (!cloudName || !apiKey || !apiSecret) throw new Error('cloudinary-secret-not-configured');
  const assets = [];
  let nextCursor = '';
  do {
    const query = new URLSearchParams({ type: 'upload', prefix: `huhs_users/${uid}/`, max_results: '500' });
    if (nextCursor) query.set('next_cursor', nextCursor);
    const response = await fetchImpl(`https://api.cloudinary.com/v1_1/${cloudName}/resources/image/upload?${query}`, {
      headers: { Authorization: `Basic ${Buffer.from(`${apiKey}:${apiSecret}`).toString('base64')}` },
    });
    const result = await response.json().catch(() => ({}));
    if (!response.ok || !Array.isArray(result.resources)) {
      throw cloudinaryFailure('cloudinary-list-temporary-failure', response, result, 'resources');
    }
    assets.push(...result.resources
      .filter((asset) => typeof asset.public_id === 'string' && asset.public_id.startsWith(`huhs_users/${uid}/`))
      .map((asset) => ({ publicId: asset.public_id, secureUrl: asset.secure_url || '' })));
    nextCursor = typeof result.next_cursor === 'string' ? result.next_cursor : '';
  } while (nextCursor);
  return assets;
}

module.exports = { cloudinarySignature, selectOwnedCloudinaryAssets, destroyCloudinaryAsset, listOwnedCloudinaryAssets };

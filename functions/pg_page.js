/**
 * Public landing page for a PG's registration QR code.
 * Served at /pg/{pgId}; installed apps intercept the same URL as an app link,
 * everyone else lands here and continues in the web app.
 * (PGs are stored in the legacy `libraries` collection.)
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const SITE = 'https://pg-sathi.web.app';
const PLAY_STORE = 'https://play.google.com/store/apps/details?id=in.pgsathi.app';
const PACKAGE_NAME = 'in.pgsathi.app';
const ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

const FACILITIES = [
  ['hasWifi', 'WiFi'],
  ['hasAC', 'AC'],
  ['hasPowerBackup', 'Power backup'],
  ['hasWashroom', 'Washroom'],
  ['hasDrinkingWater', 'Drinking water'],
  ['hasCCTV', 'CCTV'],
];

const esc = (value) =>
  String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));

function page({ title, body, script = '' }) {
  return `<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} - PG Sathi</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0F1419;color:#E6EDF3;min-height:100vh}
.wrap{max-width:480px;margin:0 auto;padding:16px}
.hero{width:100%;height:200px;object-fit:cover;border-radius:16px;margin-bottom:16px;background:#1A222B}
.card{background:#171E26;border:1px solid #2A343F;border-radius:16px;padding:20px;margin-bottom:16px}
h1{font-size:1.4rem;margin-bottom:4px}
.muted{color:#8B98A5;font-size:.9rem}
.chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:12px}
.chip{background:#1A222B;color:#8B98A5;border:1px solid #2A343F;border-radius:999px;padding:6px 12px;font-size:.8rem;font-weight:600}
.price{font-size:1.1rem;font-weight:700;margin-top:12px}
.btn{display:block;text-align:center;text-decoration:none;font-weight:700;border-radius:12px;padding:14px;margin-top:12px}
.primary{background:#14B8A6;color:#062925}
.secondary{background:transparent;color:#E6EDF3;border:1px solid #2A343F}
</style></head><body><div class="wrap">${body}</div>${script}</body></html>`;
}

// Android intent link: opens the app if installed, else the web app.
function androidIntentUrl(id) {
  const fallback = encodeURIComponent(`${SITE}/app/#/pg/${id}`);
  return `intent://pg-sathi.web.app/pg/${encodeURIComponent(id)}#Intent;scheme=https;package=${PACKAGE_NAME};S.browser_fallback_url=${fallback};end`;
}

function pgBody(id, pg, isAndroid) {
  const photo = (pg.photos || []).find((u) => /^https:\/\//.test(u));
  const place = pg.area || pg.fullAddress || pg.location || '';
  const chips = FACILITIES.filter(([key]) => pg[key])
    .map(([, label]) => `<span class="chip">${esc(label)}</span>`).join('');
  const price = pg.customMonthlyPrice
    ? `<div class="price">From &#8377;${esc(Math.round(pg.customMonthlyPrice))} / month</div>` : '';
  const phone = pg.ownerPhone
    ? `<a class="btn secondary" href="tel:${esc(pg.ownerPhone)}">Call ${esc(pg.ownerPhone)}</a>` : '';
  const cta = isAndroid ? androidIntentUrl(id) : `${SITE}/app/#/pg/${encodeURIComponent(id)}`;
  return `${photo ? `<img class="hero" src="${esc(photo)}" alt="">` : ''}
<div class="card"><h1>${esc(pg.name)}</h1><p class="muted">${esc(place)}</p>
<div class="chips">${chips}</div>${price}
<a class="btn primary" href="${cta}">Request a bed</a>${phone}</div>
<div class="card"><p class="muted">Prefer the app? Install PG Sathi to manage your stay.</p>
<a class="btn secondary" href="${PLAY_STORE}">Google Play</a></div>`;
}

exports.getPgPage = functions.https.onRequest(async (req, res) => {
  const id = req.path.split('/').filter(Boolean).pop() || '';
  if (!ID_PATTERN.test(id)) {
    res.status(404).send(page({ title: 'Not found', body: '<div class="card"><h1>PG not found</h1></div>' }));
    return;
  }

  try {
    const snap = await admin.firestore().collection('libraries').doc(id).get();
    if (!snap.exists) {
      res.status(404).set('Cache-Control', 'public, max-age=60').send(
        page({ title: 'Not found', body: '<div class="card"><h1>PG not found</h1><p class="muted">Please check the QR code and try again.</p></div>' }),
      );
      return;
    }
    const pg = snap.data();
    const isAndroid = /android/i.test(req.get('user-agent') || '');
    const script = isAndroid
      ? `<script>window.location.replace(${JSON.stringify(androidIntentUrl(id))});</script>`
      : '';
    res.status(200).set('Cache-Control', 'private, max-age=300').send(
      page({ title: pg.name, body: pgBody(id, pg, isAndroid), script }),
    );
  } catch (err) {
    console.error('[getPgPage] Error:', err);
    res.status(500).send(page({ title: 'Error', body: '<div class="card"><h1>Something went wrong</h1></div>' }));
  }
});

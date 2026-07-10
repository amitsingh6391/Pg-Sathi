#!/usr/bin/env node
/**
 * One-shot driver: runs the SarkariResult scraper end-to-end against
 * production Firestore using Application Default Credentials. Used to
 * populate the inbox immediately after deploy without waiting for the
 * 2-hour scheduled tick.
 *
 * Usage:
 *   gcloud auth application-default login          # one-time setup
 *   node scripts/run_sarkari_scrape_now.js          # dry run, prints plan
 *   node scripts/run_sarkari_scrape_now.js --apply  # writes to Firestore
 *
 * Idempotent: candidates are deduped by `normalizedKey` against the
 * existing `jobAlertCandidates` collection. Re-runs are no-ops if the
 * upstream listing hasn't changed.
 */

const { Firestore, Timestamp, FieldValue } = require('@google-cloud/firestore');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'academic-master';
const APPLY = process.argv.includes('--apply');
const MAX_ITEMS = (() => {
  const a = process.argv.find((x) => x.startsWith('--max='));
  return a ? Math.max(1, parseInt(a.split('=')[1], 10)) : 30;
})();

// ---------------------------------------------------------------------------
// Re-extract scraper helpers from index.js so this script always runs
// the same code that the deployed Cloud Function does.
// ---------------------------------------------------------------------------

const indexSource = fs.readFileSync(
  path.join(__dirname, '..', 'index.js'),
  'utf8',
);
const blockStart = indexSource.indexOf('// SarkariResult.com scraper');
const fnStart = indexSource.indexOf('function _runJobSourcesFetch');
if (blockStart === -1 || fnStart === -1) {
  console.error('Could not locate scraper block in index.js');
  process.exit(1);
}
const jsdocStart = indexSource.lastIndexOf('/**', fnStart);
const lastBrace = indexSource.lastIndexOf('}', jsdocStart);
const block = indexSource.substring(blockStart, lastBrace + 1);

// Helper used by the scraper but defined elsewhere in index.js — we
// inline the same implementation here to keep the eval body self-contained.
const _normalizeJobTitleForKeyImpl = `
function _normalizeJobTitleForKey(title) {
  if (!title) return null;
  const lowered = String(title).toLowerCase();
  const alnum = lowered.replace(/[^a-z0-9]+/g, '');
  if (alnum.length === 0) return null;
  return alnum.length > 40 ? alnum.substring(0, 40) : alnum;
}
function _inferJobCategory(title) {
  const t = String(title || '').toLowerCase();
  if (t.includes('ssc')) return 'ssc';
  if (t.includes('ibps') || t.includes('rbi') || t.includes('bank')) return 'banking';
  if (t.includes('railway') || t.includes('rrb')) return 'railway';
  if (t.includes('upsc')) return 'upsc';
  if (t.includes('police') || t.includes('constable')) return 'police';
  if (t.includes('teacher') || t.includes('tet') || t.includes('eligibility test')) return 'teaching';
  if (t.includes('army') || t.includes('navy') || t.includes('air force')) return 'defense';
  return 'other';
}
`;

const sandbox = `
  const admin = arguments[0];
  const axios = arguments[1];
  ${_normalizeJobTitleForKeyImpl}
  ${block}
  return {
    _parseSarkariListing,
    _parseSarkariDetail,
    _detailToFirestore,
    _pickLinkUrlByKind,
    _normalizeJobTitleForKey,
    _inferJobCategory,
    SARKARI_SOURCE_ID,
    SARKARI_LISTING_URL,
    SARKARI_USER_AGENT,
  };
`;

// Stub firebase-admin's Timestamp/FieldValue with the @google-cloud/firestore
// equivalents so persisted dates roundtrip correctly.
const stubAdmin = {
  firestore: {
    Timestamp,
    FieldValue,
  },
};

// eslint-disable-next-line no-new-func
const helpers = new Function(sandbox)(stubAdmin, axios);
const {
  _parseSarkariListing,
  _parseSarkariDetail,
  _detailToFirestore,
  _pickLinkUrlByKind,
  _normalizeJobTitleForKey,
  _inferJobCategory,
  SARKARI_SOURCE_ID,
  SARKARI_LISTING_URL,
  SARKARI_USER_AGENT,
} = helpers;

// ---------------------------------------------------------------------------
// Firestore + main flow
// ---------------------------------------------------------------------------

const db = new Firestore({ projectId: PROJECT_ID });

async function fetchHtml(url) {
  return (await axios.get(url, {
    timeout: 15000,
    headers: {
      'User-Agent': SARKARI_USER_AGENT,
      Accept: 'text/html,application/xhtml+xml',
    },
    maxContentLength: 2 * 1024 * 1024,
  })).data;
}

(async () => {
  console.log(`Mode: ${APPLY ? 'APPLY (writes will be made)' : 'DRY RUN'}`);
  console.log(`Project: ${PROJECT_ID}`);
  console.log(`Max items to process: ${MAX_ITEMS}\n`);

  const html = await fetchHtml(SARKARI_LISTING_URL);
  const listing = _parseSarkariListing(html, MAX_ITEMS);
  console.log(`Listing: ${listing.length} items`);

  let plannedNew = 0;
  let detailFailures = 0;
  const samples = [];

  for (const item of listing) {
    const normKey = _normalizeJobTitleForKey(item.title);
    if (!normKey) continue;
    const existing = await db
      .collection('jobAlertCandidates')
      .where('normalizedKey', '==', normKey)
      .limit(1)
      .get();
    if (!existing.empty) continue;

    let detail = null;
    try {
      const detailHtml = await fetchHtml(item.url);
      detail = _parseSarkariDetail(detailHtml);
    } catch (e) {
      detailFailures += 1;
      console.warn(`  [detail-fail] ${item.url}: ${e.message}`);
    }

    const extractedFields = detail ? _detailToFirestore(detail) : null;
    const applyUrl = detail
      ? _pickLinkUrlByKind(detail.links, 'apply')
      : null;
    const officialUrl = detail
      ? _pickLinkUrlByKind(detail.links, 'official')
      : null;

    const payload = {
      sourceId: SARKARI_SOURCE_ID,
      rawTitle: item.title,
      rawLink: item.url,
      rawDescription: detail ? detail.shortInfo || null : null,
      rawPublishedAt: null,
      fetchedAt: FieldValue.serverTimestamp(),
      status: 'pending',
      suggestedCategory: _inferJobCategory(item.title),
      suggestedApplyUrl: applyUrl || officialUrl || null,
      publishedJobAlertId: null,
      ignoredReason: null,
      reviewedBy: null,
      reviewedAt: null,
      normalizedKey: normKey,
      extractedFields,
    };

    plannedNew += 1;
    if (samples.length < 5) {
      samples.push({
        title: item.title.substring(0, 60),
        vacancies: detail ? detail.vacancies : null,
        feeKeys: detail ? Object.keys(detail.fees || {}) : [],
        applyUrl: payload.suggestedApplyUrl,
      });
    }

    if (APPLY) {
      await db.collection('jobAlertCandidates').add(payload);
    }
  }

  console.log('\nSamples:');
  for (const s of samples) {
    console.log(
      `  - ${s.title} | vac=${s.vacancies} | fees=${s.feeKeys.join(',') || 'none'} | apply=${s.applyUrl || 'none'}`,
    );
  }

  console.log(
    `\nDone. plannedNew=${plannedNew} detailFailures=${detailFailures} ` +
      `mode=${APPLY ? 'APPLIED' : 'DRY-RUN (use --apply to write)'}`,
  );

  if (APPLY) {
    await db.collection('jobAlertSources').doc(SARKARI_SOURCE_ID).set(
      {
        name: 'SarkariResult.com',
        url: SARKARI_LISTING_URL,
        kind: 'sarkari_scraper',
        isActive: true,
        lastFetchedAt: FieldValue.serverTimestamp(),
        lastFetchStatus: 'success',
        lastError: null,
        itemsFoundLastRun: plannedNew,
        detailFailures,
      },
      { merge: true },
    );
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});

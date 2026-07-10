/**
 * One-shot backfill: populates `suggestedApplyUrl` on existing
 * `jobAlertCandidates` documents that were ingested before the
 * extraction heuristic shipped.
 *
 * Why this exists:
 *   `_runJobSourcesFetch` dedups by `normalizedKey`, so simply
 *   re-running the fetch will skip every candidate already in
 *   the inbox — they'd never get the new field. We must re-pull
 *   each source's RSS, match items back to existing candidates
 *   by `normalizedKey`, and patch the field directly.
 *
 * SAFE: dry-run by default. Pass --apply to actually write.
 *
 * Usage:
 *   node scripts/backfill_apply_urls.js          # dry-run
 *   node scripts/backfill_apply_urls.js --apply  # write updates
 *
 * Idempotent: only updates docs where `suggestedApplyUrl` is missing
 * or empty. Re-runs after that are no-ops.
 */

const { Firestore } = require('@google-cloud/firestore');
const { OAuth2Client } = require('google-auth-library');
const axios = require('axios');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'academic-master';

// ---------------------------------------------------------------------------
// Heuristics — kept identical to functions/index.js so behaviour matches
// what the live Cloud Function does for new fetches. If you change one,
// change both.
// ---------------------------------------------------------------------------

const _OFFICIAL_HOST_SUFFIXES = [
  '.gov.in',
  '.nic.in',
  '.ac.in',
  '.edu.in',
  '.res.in',
  '.org.in',
  '.edu',
];
const _AGGREGATOR_HOSTS = new Set([
  'freejobalert.com',
  'www.freejobalert.com',
  'jagranjosh.com',
  'www.jagranjosh.com',
  'sarkariresult.com',
  'www.sarkariresult.com',
  'employmentnews.gov.in',
  'www.employmentnews.gov.in',
]);

function _hostMatchesOfficialSuffix(host) {
  if (!host) return false;
  return _OFFICIAL_HOST_SUFFIXES.some(
    (s) => host === s.slice(1) || host.endsWith(s)
  );
}
function _isUsableApplyHost(host) {
  if (!host) return false;
  if (_AGGREGATOR_HOSTS.has(host)) return false;
  return _hostMatchesOfficialSuffix(host);
}

function _extractApplyUrl(rawHtml) {
  if (!rawHtml) return null;
  const hrefRegex = /href\s*=\s*["']([^"']+)["']/gi;
  let match;
  while ((match = hrefRegex.exec(rawHtml)) !== null) {
    const raw = match[1].replace(/&amp;/g, '&').trim();
    if (!raw) continue;
    let url;
    try {
      url = new URL(raw);
    } catch (_) {
      continue;
    }
    if (url.protocol !== 'http:' && url.protocol !== 'https:') continue;
    if (_isUsableApplyHost(url.hostname.toLowerCase())) return url.toString();
  }

  const text = rawHtml
    .replace(/<!\[CDATA\[|\]\]>/g, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&nbsp;/g, ' ');
  const hostRegex = /\b((?:[a-z0-9][a-z0-9-]*\.)+[a-z][a-z0-9-]*)\b/gi;
  while ((match = hostRegex.exec(text)) !== null) {
    const host = match[1].toLowerCase().replace(/[.,;)]+$/, '');
    if (!_isUsableApplyHost(host)) continue;
    return 'https://' + host;
  }
  return null;
}

function _normalizeJobTitleForKey(title) {
  if (!title) return '';
  const lowered = String(title).toLowerCase();
  const alnum = lowered.replace(/[^a-z0-9]+/g, '');
  return alnum.length > 40 ? alnum.substring(0, 40) : alnum;
}

/**
 * Yields { title, descHtml, contentHtml } for each <item> in the feed.
 * Unlike the production parser this keeps the raw HTML so we can run
 * extraction on it; the production parser strips HTML before storing,
 * which is why we can't backfill from `rawDescription` alone.
 */
function* _iterateRssItems(xml) {
  const itemRegex = /<item[\s>]([\s\S]*?)<\/item>/g;
  const stripCdata = (s) =>
    (s || '').replace(/<!\[CDATA\[|\]\]>/g, '').trim();
  const cleanText = (s) =>
    stripCdata(s)
      .replace(/<[^>]+>/g, '')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .trim();
  let m;
  while ((m = itemRegex.exec(xml)) !== null) {
    const inner = m[1];
    const titleMatch = inner.match(/<title[^>]*>([\s\S]*?)<\/title>/);
    const descMatch = inner.match(
      /<description[^>]*>([\s\S]*?)<\/description>/
    );
    const contentMatch = inner.match(
      /<content:encoded[^>]*>([\s\S]*?)<\/content:encoded>/
    );
    yield {
      title: cleanText(titleMatch && titleMatch[1]),
      descHtml: stripCdata(descMatch && descMatch[1]),
      contentHtml: stripCdata(contentMatch && contentMatch[1]),
    };
  }
}

function createCredentials() {
  const configPath = path.join(
    process.env.HOME || '',
    '.config/configstore/firebase-tools.json'
  );
  if (!fs.existsSync(configPath)) {
    throw new Error('Firebase CLI config not found. Run: firebase login');
  }
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const refreshToken = (config.tokens || {}).refresh_token;
  if (!refreshToken) {
    throw new Error('No refresh token. Run: firebase login');
  }
  const clientId =
    '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
  const clientSecret = 'j9iVZfS8kkCEFUPaAeJV0sAi';
  const oauth2Client = new OAuth2Client(clientId, clientSecret);
  oauth2Client.setCredentials({ refresh_token: refreshToken });
  return oauth2Client;
}

async function main() {
  const applyChanges = process.argv.includes('--apply');
  const authClient = createCredentials();
  const db = new Firestore({ projectId: PROJECT_ID, authClient });

  console.log('\n=== Backfill suggestedApplyUrl ===');
  console.log('Mode: ' + (applyChanges ? 'APPLY (will write)' : 'DRY-RUN'));
  console.log('Project: ' + PROJECT_ID + '\n');

  // 1. Build a lookup of candidates that still need a suggestedApplyUrl.
  const candidatesSnap = await db.collection('jobAlertCandidates').get();
  /** @type {Map<string, FirebaseFirestore.DocumentReference>} */
  const needsBackfillByKey = new Map();
  let alreadyHas = 0;
  let missingKey = 0;
  for (const doc of candidatesSnap.docs) {
    const data = doc.data();
    const normKey = data.normalizedKey;
    if (!normKey) {
      missingKey++;
      continue;
    }
    const existing = data.suggestedApplyUrl;
    if (existing && String(existing).trim() !== '') {
      alreadyHas++;
      continue;
    }
    // Last write wins on dup keys (shouldn't happen, but defensive).
    needsBackfillByKey.set(normKey, doc.ref);
  }
  console.log(
    'Candidates: ' +
      candidatesSnap.size +
      ' total | ' +
      needsBackfillByKey.size +
      ' need backfill | ' +
      alreadyHas +
      ' already have URL | ' +
      missingKey +
      ' missing normalizedKey\n'
  );
  if (needsBackfillByKey.size === 0) {
    console.log('Nothing to backfill. Done.');
    process.exit(0);
  }

  // 2. Re-pull each active source's RSS and match items to candidates.
  const sourcesSnap = await db
    .collection('jobAlertSources')
    .where('isActive', '==', true)
    .get();

  const updates = []; // { ref, suggestedApplyUrl, title }
  const sourceSummaries = [];
  for (const sourceDoc of sourcesSnap.docs) {
    const source = { id: sourceDoc.id, ...sourceDoc.data() };
    let matched = 0;
    let extracted = 0;
    let fetchError = null;
    try {
      const response = await axios.get(source.url, {
        timeout: 15000,
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; JobAlertBot/1.0)',
        },
      });
      for (const item of _iterateRssItems(response.data)) {
        const normKey = _normalizeJobTitleForKey(item.title);
        if (!normKey) continue;
        const ref = needsBackfillByKey.get(normKey);
        if (!ref) continue;
        matched++;
        const url =
          _extractApplyUrl(item.contentHtml) ||
          _extractApplyUrl(item.descHtml);
        if (url) {
          extracted++;
          updates.push({ ref, suggestedApplyUrl: url, title: item.title });
          // Don't double-update if the same key shows up in another feed.
          needsBackfillByKey.delete(normKey);
        }
      }
    } catch (err) {
      fetchError = err.message || String(err);
    }
    sourceSummaries.push({
      id: source.id,
      matched,
      extracted,
      error: fetchError,
    });
  }

  console.log('Per-source results:');
  console.log('-'.repeat(80));
  for (const s of sourceSummaries) {
    const tag = s.error ? 'ERROR ' : 'OK    ';
    console.log(
      '  ' +
        tag +
        ' | ' +
        s.id.padEnd(22) +
        ' | matched=' +
        String(s.matched).padStart(3) +
        ' | extracted=' +
        String(s.extracted).padStart(3) +
        (s.error ? ' | ' + s.error : '')
    );
  }
  console.log('-'.repeat(80));
  console.log(
    '\nTotal updates planned: ' +
      updates.length +
      ' (out of ' +
      candidatesSnap.size +
      ' total candidates)\n'
  );
  if (updates.length === 0) {
    console.log('No URLs found in any RSS payload. Done.');
    process.exit(0);
  }

  // Sample for human review.
  const sampleSize = Math.min(5, updates.length);
  console.log('Sample (first ' + sampleSize + '):');
  for (let i = 0; i < sampleSize; i++) {
    const u = updates[i];
    console.log('  - ' + u.title.substring(0, 60));
    console.log('      -> ' + u.suggestedApplyUrl);
  }
  console.log('');

  if (!applyChanges) {
    console.log('DRY-RUN complete. No changes made.');
    console.log('To apply: node scripts/backfill_apply_urls.js --apply\n');
    process.exit(0);
  }

  // 3. Commit in batches of 400 (Firestore limit is 500 ops / batch).
  const BATCH_SIZE = 400;
  let written = 0;
  for (let i = 0; i < updates.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = updates.slice(i, i + BATCH_SIZE);
    for (const u of chunk) {
      batch.update(u.ref, { suggestedApplyUrl: u.suggestedApplyUrl });
    }
    await batch.commit();
    written += chunk.length;
    console.log('  committed ' + written + ' / ' + updates.length);
  }
  console.log('\nBackfill complete. Updated ' + written + ' candidates.\n');
  process.exit(0);
}

main().catch((err) => {
  console.error('Error:', err.message || err);
  process.exit(1);
});

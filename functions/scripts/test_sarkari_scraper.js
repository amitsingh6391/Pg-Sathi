#!/usr/bin/env node
/**
 * Smoke-tests the SarkariResult scraper against the live site by
 * `require`ing the parser helpers exported from `index.js`. Run before
 * deploy to confirm upstream HTML hasn't drifted away from our regexes.
 *
 *   node scripts/test_sarkari_scraper.js                  # 5 detail pages
 *   node scripts/test_sarkari_scraper.js --max=3          # 3 detail pages
 */

const axios = require('axios');
const path = require('path');
const fs = require('fs');

// Pull the parser helper bodies out of index.js (they are not
// `module.exports`-ed because they're internal Cloud Function
// utilities). Slicing by stable banner lines keeps this script
// resilient to surrounding edits.
const indexSource = fs.readFileSync(
  path.join(__dirname, '..', 'index.js'),
  'utf8',
);
const start = indexSource.indexOf('// SarkariResult.com scraper');
const fnStart = indexSource.indexOf('function _runJobSourcesFetch');
if (start === -1 || fnStart === -1) {
  console.error('Could not locate scraper block in index.js');
  process.exit(1);
}
// Walk back to the JSDoc opener that introduces _runJobSourcesFetch,
// then to the closing brace of the previous scraper helper so the
// next function's JSDoc (which contains stray `{...}` in @param) is
// not pulled into the eval body.
const jsdocStart = indexSource.lastIndexOf('/**', fnStart);
const lastBrace = indexSource.lastIndexOf('}', jsdocStart);
const block = indexSource.substring(start, lastBrace + 1);

// Eval the block as a CommonJS module body — provide a stub `admin`
// so any Firestore Timestamp call inside the helpers doesn't crash.
const stubAdmin = {
  firestore: {
    FieldValue: { serverTimestamp: () => null },
    Timestamp: { fromDate: (d) => d },
  },
};
const sandbox = `
  const admin = arguments[0];
  const axios = arguments[1];
  ${block}
  return { _parseSarkariListing, _parseSarkariDetail };
`;
// eslint-disable-next-line no-new-func
const scrap = new Function(sandbox)(stubAdmin, axios);
const { _parseSarkariListing, _parseSarkariDetail } = scrap;

// ---------------------------------------------------------------------------

const argv = process.argv.slice(2);
const maxArg = argv.find((a) => a.startsWith('--max='));
const MAX_DETAILS = maxArg ? parseInt(maxArg.split('=')[1], 10) : 5;

const LISTING_URL = 'https://www.sarkariresult.com/latestjob/';
const UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ' +
  'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15';

async function get(url) {
  return (await axios.get(url, {
    timeout: 15000,
    headers: { 'User-Agent': UA, Accept: 'text/html,application/xhtml+xml' },
  })).data;
}

(async () => {
  console.log(`[test] Fetching listing: ${LISTING_URL}`);
  const html = await get(LISTING_URL);
  const items = _parseSarkariListing(html, 50);
  console.log(`[test] Listing parsed: ${items.length} items`);
  console.log(items
    .slice(0, 5)
    .map((i, idx) => `  ${idx + 1}. ${i.title.substring(0, 60)} | last: ${i.lastDateRaw}`)
    .join('\n'));

  let ok = 0;
  let fail = 0;
  for (let i = 0; i < Math.min(MAX_DETAILS, items.length); i++) {
    const item = items[i];
    try {
      const detailHtml = await get(item.url);
      const detail = _parseSarkariDetail(detailHtml);
      if (!detail) {
        console.log(`[test] ${item.url} -> not a job page (skipped)`);
        continue;
      }
      ok += 1;
      console.log('---');
      console.log(`title:    ${detail.title.substring(0, 80)}`);
      console.log(`vac:      ${detail.vacancies}`);
      console.log(`startEnd: ${detail.applicationStartRaw} → ${detail.applicationEndRaw}`);
      console.log(`feeLast:  ${detail.feeLastDateRaw}`);
      console.log(`age:      ${JSON.stringify(detail.age)}`);
      console.log(`fees:     ${JSON.stringify(detail.fees)}`);
      const apply = detail.links.find((l) => l.kind === 'apply');
      console.log(`links:    ${detail.links.length} (apply=${apply ? apply.url : 'none'})`);
    } catch (e) {
      fail += 1;
      console.warn(`[test] FAIL ${item.url}: ${e.message}`);
    }
  }
  console.log(`---\n[test] DONE  ok=${ok}  fail=${fail}`);
})().catch((e) => {
  console.error(e);
  process.exit(1);
});

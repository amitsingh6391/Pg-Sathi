#!/usr/bin/env node
/* eslint-disable no-console */

/**
 * Smoke test for the type-aware ingestion validator
 * (`_hasMinimumDataForType` in functions/index.js).
 *
 * Functions in `functions/index.js` aren't exported (they live alongside
 * the Firebase callable surface), so we re-evaluate the validator's
 * source in this script's scope rather than `require`ing the file.
 * The function is intentionally pure — no Firestore / admin SDK
 * dependency — so this works without authentication.
 *
 * Run:  `node functions/scripts/test_type_validator.js`
 *
 * The script exits 0 on success, 1 on assertion failure.
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const indexPath = path.join(__dirname, '..', 'index.js');
const source = fs.readFileSync(indexPath, 'utf8');

// Snip the validator out by name. Block extraction stops at the next
// top-level `function ` declaration so we don't slurp the rest of the
// file (which would pull in firebase-admin imports we can't resolve).
const fnRe =
  /function _hasMinimumDataForType\([\s\S]*?\n\}\n/;
const match = source.match(fnRe);
if (!match) {
  console.error('Could not locate _hasMinimumDataForType in index.js');
  process.exit(1);
}

// eslint-disable-next-line no-eval
const _hasMinimumDataForType = eval(`(${match[0].replace(/^function /, 'function ')})`);

const tests = [];
function test(name, fn) {
  tests.push({ name, fn });
}

// ---------- recruitment ----------
// Strict mode: must have ALL THREE of (age, fees, applicationEndDate).

const fullRecruitment = {
  age: { min: 21, max: 30 },
  fees: { General: 500 },
  applicationEndDate: new Date('2026-12-31'),
};

test('recruitment: passes when age + fees + applicationEndDate all present', () => {
  const r = _hasMinimumDataForType(fullRecruitment, 'recruitment');
  assert.strictEqual(r.ok, true);
});

test('recruitment: drops when age missing', () => {
  const r = _hasMinimumDataForType(
    { ...fullRecruitment, age: {} },
    'recruitment',
  );
  assert.strictEqual(r.ok, false);
  assert.ok(r.reason.includes('age'), `reason was: ${r.reason}`);
});

test('recruitment: drops when fees missing', () => {
  const r = _hasMinimumDataForType(
    { ...fullRecruitment, fees: {} },
    'recruitment',
  );
  assert.strictEqual(r.ok, false);
  assert.ok(r.reason.includes('fees'), `reason was: ${r.reason}`);
});

test('recruitment: drops when applicationEndDate missing', () => {
  const r = _hasMinimumDataForType(
    { ...fullRecruitment, applicationEndDate: null },
    'recruitment',
  );
  assert.strictEqual(r.ok, false);
  assert.ok(r.reason.includes('endDate'), `reason was: ${r.reason}`);
});

test('recruitment: drops when only vacancies are present (no longer enough)', () => {
  const r = _hasMinimumDataForType(
    { vacancies: 100, fees: {}, age: {} },
    'recruitment',
  );
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.reason, 'recruitment_missing:endDate,fees,age');
});

test('recruitment: drops empty detail entirely', () => {
  const r = _hasMinimumDataForType(
    { fees: {}, age: {}, links: [] },
    'recruitment',
  );
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.reason, 'recruitment_missing:endDate,fees,age');
});

test('recruitment: drops null detail (detail page failed to load)', () => {
  const r = _hasMinimumDataForType(null, 'recruitment');
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.reason, 'no_detail_parsed');
});

test('recruitment: passes with only ageMin (max may be missing on some posts)', () => {
  const r = _hasMinimumDataForType(
    { ...fullRecruitment, age: { min: 18 } },
    'recruitment',
  );
  assert.strictEqual(r.ok, true);
});

// ---------- result ----------

test('result: passes when a typed result link is present', () => {
  const r = _hasMinimumDataForType(
    { links: [{ kind: 'result', url: 'https://x.test/r' }] },
    'result',
  );
  assert.strictEqual(r.ok, true);
});

test('result: passes when any link + meaningful shortInfo', () => {
  const r = _hasMinimumDataForType(
    {
      links: [{ kind: 'official', url: 'https://x.test/o' }],
      shortInfo: 'Result of SSC CGL Tier 1 declared on 1 May 2026',
    },
    'result',
  );
  assert.strictEqual(r.ok, true);
});

test('result: drops when zero links AND empty shortInfo', () => {
  const r = _hasMinimumDataForType(
    { links: [], shortInfo: '' },
    'result',
  );
  assert.strictEqual(r.ok, false);
  assert.strictEqual(r.reason, 'result_missing_link_or_info');
});

// ---------- admit card ----------

test('admitCard: passes when typed admit-card link present', () => {
  const r = _hasMinimumDataForType(
    { links: [{ kind: 'admitCard', url: 'https://x.test/a' }] },
    'admitCard',
  );
  assert.strictEqual(r.ok, true);
});

test('admitCard: drops when only an unrelated link is present', () => {
  const r = _hasMinimumDataForType(
    {
      links: [{ kind: 'syllabus', url: 'https://x.test/s' }],
      shortInfo: 'short',
    },
    'admitCard',
  );
  assert.strictEqual(r.ok, false);
});

// ---------- runner ----------

let failed = 0;
for (const t of tests) {
  try {
    t.fn();
    console.log(`ok  ${t.name}`);
  } catch (err) {
    failed += 1;
    console.error(`FAIL ${t.name}\n     ${err.message}`);
  }
}

if (failed > 0) {
  console.error(`\n${failed}/${tests.length} tests failed`);
  process.exit(1);
}
console.log(`\n${tests.length}/${tests.length} tests passed`);

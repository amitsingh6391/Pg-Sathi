#!/usr/bin/env node
/* eslint-disable no-console */

/**
 * Smoke test for the daily-digest picker
 * (`_pickDigestForUser` + `_buildDigestNotification` in
 * functions/index.js). Both are pure — no Firestore / FCM
 * dependency — so they can be re-evaluated in this script's
 * sandbox without auth.
 *
 * Run:  `node functions/scripts/test_digest_picker.js`
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

const indexPath = path.join(__dirname, '..', 'index.js');
const source = fs.readFileSync(indexPath, 'utf8');

function extract(name) {
  const re = new RegExp(`function ${name}\\([\\s\\S]*?\\n\\}\\n`);
  const match = source.match(re);
  if (!match) throw new Error(`Could not locate ${name} in index.js`);
  // eslint-disable-next-line no-eval
  return eval(`(${match[0].replace(/^function /, 'function ')})`);
}

const _pickDigestForUser = extract('_pickDigestForUser');
const _buildDigestNotification = extract('_buildDigestNotification');
const _resolveEffectivePrefs = extract('_resolveEffectivePrefs');

const tests = [];
function test(name, fn) {
  tests.push({ name, fn });
}

const recent = [
  { id: 'a', title: 'SSC CGL 2026', category: 'ssc', priority: 9 },
  { id: 'b', title: 'IBPS PO', category: 'banking', priority: 7 },
  { id: 'c', title: 'RRB NTPC', category: 'railway', priority: 5 },
  { id: 'd', title: 'UPSC CSE', category: 'upsc', priority: 8 },
  { id: 'e', title: 'SSC GD', category: 'ssc', priority: 6 },
];

// ---------- _pickDigestForUser ----------

test('returns null when push disabled', () => {
  const r = _pickDigestForUser(
    { pushEnabled: false, frequency: 'digest9am', categories: [] },
    recent,
  );
  assert.strictEqual(r, null);
});

test('returns null when frequency is not digest9am', () => {
  const r = _pickDigestForUser(
    { pushEnabled: true, frequency: 'instant', categories: [] },
    recent,
  );
  assert.strictEqual(r, null);
});

test('returns null when frequency is off', () => {
  const r = _pickDigestForUser(
    { pushEnabled: true, frequency: 'off', categories: [] },
    recent,
  );
  assert.strictEqual(r, null);
});

test('returns null when prefs object is null', () => {
  const r = _pickDigestForUser(null, recent);
  assert.strictEqual(r, null);
});

test('empty categories means subscribe to all', () => {
  const r = _pickDigestForUser(
    { pushEnabled: true, frequency: 'digest9am', categories: [] },
    recent,
  );
  assert.strictEqual(r.matchCount, recent.length);
  assert.deepStrictEqual(
    r.top.map(j => j.id),
    ['a', 'd', 'b'], // priority desc: 9, 8, 7
  );
});

test('filters to subscribed categories only', () => {
  const r = _pickDigestForUser(
    {
      pushEnabled: true,
      frequency: 'digest9am',
      categories: ['ssc', 'banking'],
    },
    recent,
  );
  assert.strictEqual(r.matchCount, 3); // a, b, e
  assert.deepStrictEqual(
    r.top.map(j => j.id),
    ['a', 'b', 'e'], // priority desc within ssc+banking
  );
});

test('returns null when categories filter excludes everything', () => {
  const r = _pickDigestForUser(
    { pushEnabled: true, frequency: 'digest9am', categories: ['defense'] },
    recent,
  );
  assert.strictEqual(r, null);
});

test('topN cap honoured (default 3)', () => {
  const r = _pickDigestForUser(
    { pushEnabled: true, frequency: 'digest9am', categories: [] },
    recent,
  );
  assert.strictEqual(r.top.length, 3);
});

test('topN cap honoured (override)', () => {
  const r = _pickDigestForUser(
    { pushEnabled: true, frequency: 'digest9am', categories: [] },
    recent,
    { topN: 1 },
  );
  assert.strictEqual(r.top.length, 1);
  assert.strictEqual(r.top[0].id, 'a');
});

// ---------- _resolveEffectivePrefs ----------

test('resolve: null prefs → digest9am defaults (the silent-majority case)', () => {
  const r = _resolveEffectivePrefs(null);
  assert.deepStrictEqual(r, {
    pushEnabled: true,
    frequency: 'digest9am',
    categories: [],
  });
});

test('resolve: undefined prefs → defaults', () => {
  const r = _resolveEffectivePrefs(undefined);
  assert.strictEqual(r.frequency, 'digest9am');
  assert.strictEqual(r.pushEnabled, true);
});

test('resolve: explicit prefs pass through unchanged', () => {
  const r = _resolveEffectivePrefs({
    pushEnabled: false,
    frequency: 'instant',
    categories: ['ssc', 'banking'],
  });
  assert.deepStrictEqual(r, {
    pushEnabled: false,
    frequency: 'instant',
    categories: ['ssc', 'banking'],
  });
});

test('resolve: partial doc fills in missing fields', () => {
  // Older client wrote only categories; everything else falls back.
  const r = _resolveEffectivePrefs({ categories: ['ssc'] });
  assert.deepStrictEqual(r, {
    pushEnabled: true,
    frequency: 'digest9am',
    categories: ['ssc'],
  });
});

test('resolve: pushEnabled=false is preserved (not coerced to default true)', () => {
  const r = _resolveEffectivePrefs({ pushEnabled: false });
  assert.strictEqual(r.pushEnabled, false);
  assert.strictEqual(r.frequency, 'digest9am');
});

test('resolve: categories must be array (string is rejected as default)', () => {
  // Defensive: malformed write shouldn't crash the picker downstream.
  const r = _resolveEffectivePrefs({ categories: 'ssc' });
  assert.deepStrictEqual(r.categories, []);
});

test('resolve+pick: silent-majority user gets all recent jobs in digest', () => {
  // The whole point of this fix: a student with no prefs doc should
  // be enrolled in the 9 AM digest by default.
  const effective = _resolveEffectivePrefs(null);
  const pick = _pickDigestForUser(effective, recent);
  assert.notStrictEqual(pick, null);
  assert.strictEqual(pick.matchCount, recent.length);
});

// ---------- _buildDigestNotification ----------

test('headline-only body when matchCount == 1', () => {
  const n = _buildDigestNotification({
    matchCount: 1,
    top: [{ id: 'a', title: 'SSC CGL' }],
  });
  assert.strictEqual(n.title, '1 new alert today');
  assert.strictEqual(n.body, 'SSC CGL');
});

test('headline + extra count when matchCount > 1', () => {
  const n = _buildDigestNotification({
    matchCount: 5,
    top: [{ id: 'a', title: 'SSC CGL' }],
  });
  assert.strictEqual(n.title, '5 new alerts today');
  assert.strictEqual(n.body, 'SSC CGL + 4 more in your feed');
});

test('body truncated to 200 chars', () => {
  const longTitle = 'A'.repeat(500);
  const n = _buildDigestNotification({
    matchCount: 2,
    top: [{ id: 'a', title: longTitle }],
  });
  assert.ok(n.body.length <= 200);
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

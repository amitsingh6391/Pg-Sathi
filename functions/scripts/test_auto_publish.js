#!/usr/bin/env node
/* eslint-disable no-console */

/**
 * Smoke tests for the auto-publish gate
 * (`_isAutoPublishWorthy` + `_buildJobAlertDocFromCandidate` and
 * the small pure helpers they depend on).
 *
 * The functions live in `functions/index.js` alongside FCM /
 * Firestore code so they can't be `require()`d directly without
 * pulling in firebase-admin. We extract their text via regex and
 * re-evaluate in this sandbox — same trick used by
 * `test_digest_picker.js` and `test_type_validator.js`.
 *
 * `_buildJobAlertDocFromCandidate` references `admin.firestore.Timestamp`,
 * so we provide a tiny stub. The stub records the JS Date so tests
 * can assert on the underlying value.
 *
 * Run:  `node functions/scripts/test_auto_publish.js`
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

// Minimal firebase-admin stub — only the surfaces our functions touch.
class StubTimestamp {
  constructor(date) { this._date = date; }
  toDate() { return this._date; }
  static fromDate(d) { return new StubTimestamp(d); }
}
const admin = {
  firestore: { Timestamp: StubTimestamp },
};

const indexPath = path.join(__dirname, '..', 'index.js');
const source = fs.readFileSync(indexPath, 'utf8');

function extractFunction(name) {
  const re = new RegExp(`function ${name}\\([\\s\\S]*?\\n\\}\\n`);
  const match = source.match(re);
  if (!match) throw new Error(`Could not locate function ${name} in index.js`);
  // eslint-disable-next-line no-new-func
  return new Function('admin', `${match[0]}\nreturn ${name};`)(admin);
}

function extractConst(name) {
  const re = new RegExp(`const ${name} = [\\s\\S]*?;\\n`);
  const match = source.match(re);
  if (!match) throw new Error(`Could not locate const ${name} in index.js`);
  // eslint-disable-next-line no-new-func
  return new Function(`${match[0]}\nreturn ${name};`)();
}

// Extract pure helpers + the worthiness gate. Order matters: the
// later functions reference the earlier ones via the closure created
// inside extractFunction's `new Function`, so we re-extract everything
// that the target uses inside a single eval block.
const KNOWN = extractConst('_KNOWN_JOB_CATEGORIES');
const PER_RUN_CAP = extractConst('_AUTO_PUBLISH_PER_RUN_CAP');
const FRESH_HRS = extractConst('_AUTO_PUBLISH_FRESHNESS_HOURS');
const MIN_TITLE = extractConst('_AUTO_PUBLISH_MIN_TITLE_CHARS');
const REVIEWER_TAG = extractConst('_AUTO_PUBLISH_REVIEWER_TAG');

// Bundle helpers + main fn together so internal calls resolve.
const bundleSrc = [
  '_KNOWN_JOB_CATEGORIES',
  '_AUTO_PUBLISH_PER_RUN_CAP',
  '_AUTO_PUBLISH_FRESHNESS_HOURS',
  '_AUTO_PUBLISH_MIN_TITLE_CHARS',
  '_AUTO_PUBLISH_REVIEWER_TAG',
].map((n) => {
  const re = new RegExp(`const ${n} = [\\s\\S]*?;\\n`);
  return source.match(re)[0];
}).join('\n') +
  ['_isAutoPublishWorthy', '_toDate', '_hasLinkOfKind',
    '_buildJobAlertDocFromCandidate', '_toTimestamp', '_statusForType',
    '_formatAgeRange', '_generalFeeRupees', '_reservedFeeRupees',
    '_buildImportantLinks', '_legacyImportantLinks', '_inferOrganization',
  ].map((n) => {
    const re = new RegExp(`function ${n}\\([\\s\\S]*?\\n\\}\\n`);
    const m = source.match(re);
    if (!m) throw new Error(`Missing function ${n}`);
    return m[0];
  }).join('\n');

// eslint-disable-next-line no-new-func
const bundle = new Function('admin', bundleSrc + `
  return {
    _isAutoPublishWorthy,
    _buildJobAlertDocFromCandidate,
    _formatAgeRange,
    _inferOrganization,
    _generalFeeRupees,
    _reservedFeeRupees,
    _statusForType,
    _hasLinkOfKind,
  };
`)(admin);

const {
  _isAutoPublishWorthy,
  _buildJobAlertDocFromCandidate,
  _formatAgeRange,
  _inferOrganization,
  _generalFeeRupees,
  _statusForType,
  _hasLinkOfKind,
} = bundle;

// ---------------------------------------------------------------------------
// Test runner
// ---------------------------------------------------------------------------

const tests = [];
function test(name, fn) { tests.push({ name, fn }); }

const NOW = new Date('2026-05-02T10:00:00.000Z');
const FRESH = new Date(NOW.getTime() - 2 * 3600_000);
const STALE = new Date(NOW.getTime() - 60 * 3600_000); // > 48h

function recruitmentCandidate(overrides = {}) {
  return {
    status: 'pending',
    fetchedAt: FRESH,
    rawTitle: 'SSC CGL 2026 Recruitment Notification for 1865 Posts',
    suggestedCategory: 'ssc',
    type: 'recruitment',
    rawLink: 'https://sarkariresult.com/latestjob/ssc-cgl-2026/',
    rawDescription: 'SSC CGL 2026 short info',
    suggestedApplyUrl: 'https://ssc.gov.in/apply',
    extractedFields: {
      shortInfo: 'Apply online for SSC CGL 2026 — 1865 vacancies',
      vacancies: 1865,
      applicationStartDate: new Date('2026-05-01'),
      applicationEndDate: new Date('2026-06-15'),
      ageMin: 18,
      ageMax: 32,
      fees: { 'General / OBC / EWS': 100, 'SC / ST': 0 },
      links: [
        { label: 'Apply Online', url: 'https://ssc.gov.in/apply', kind: 'apply' },
        { label: 'Notification', url: 'https://ssc.gov.in/n.pdf', kind: 'notification' },
        { label: 'Official', url: 'https://ssc.gov.in', kind: 'official' },
      ],
    },
    ...overrides,
  };
}

function resultCandidate(overrides = {}) {
  return {
    status: 'pending',
    fetchedAt: FRESH,
    rawTitle: 'SSC CHSL 2025 Result Declared — Tier 1',
    suggestedCategory: 'ssc',
    type: 'result',
    rawLink: 'https://sarkariresult.com/result/ssc-chsl-result/',
    extractedFields: {
      links: [
        { label: 'Result', url: 'https://ssc.gov.in/r.pdf', kind: 'result' },
      ],
    },
    ...overrides,
  };
}

function admitCardCandidate(overrides = {}) {
  return {
    status: 'pending',
    fetchedAt: FRESH,
    rawTitle: 'SSC GD Constable Admit Card 2026 Released',
    suggestedCategory: 'ssc',
    type: 'admitCard',
    rawLink: 'https://sarkariresult.com/admit-card/ssc-gd/',
    extractedFields: {
      links: [
        { label: 'Admit Card', url: 'https://ssc.gov.in/ac.pdf', kind: 'admitCard' },
      ],
    },
    ...overrides,
  };
}

// ---------------------------------------------------------------------------
// Lifecycle / freshness gates
// ---------------------------------------------------------------------------

test('rejects null candidate', () => {
  const r = _isAutoPublishWorthy(null, NOW);
  assert.deepStrictEqual(r, { ok: false, reason: 'null_candidate' });
});

test('rejects already-published candidate', () => {
  const r = _isAutoPublishWorthy(
    recruitmentCandidate({ status: 'published' }), NOW);
  assert.strictEqual(r.ok, false);
  assert.match(r.reason, /^status_not_pending/);
});

test('rejects admin-ignored candidate (honour explicit decision)', () => {
  const r = _isAutoPublishWorthy(
    recruitmentCandidate({ status: 'ignored' }), NOW);
  assert.strictEqual(r.ok, false);
  assert.match(r.reason, /^status_not_pending/);
});

test('rejects candidate with no fetchedAt', () => {
  const r = _isAutoPublishWorthy(
    recruitmentCandidate({ fetchedAt: null }), NOW);
  assert.deepStrictEqual(r, { ok: false, reason: 'no_fetched_at' });
});

test('rejects stale candidate (> 48h old)', () => {
  const r = _isAutoPublishWorthy(
    recruitmentCandidate({ fetchedAt: STALE }), NOW);
  assert.strictEqual(r.ok, false);
  assert.match(r.reason, /^stale:/);
});

// ---------------------------------------------------------------------------
// Quality gates
// ---------------------------------------------------------------------------

test('rejects candidate with short title', () => {
  const r = _isAutoPublishWorthy(
    recruitmentCandidate({ rawTitle: 'Click Here' }), NOW);
  assert.strictEqual(r.ok, false);
  assert.match(r.reason, /^short_title/);
});

test('rejects candidate with category=other (needs human triage)', () => {
  const r = _isAutoPublishWorthy(
    recruitmentCandidate({ suggestedCategory: 'other' }), NOW);
  assert.strictEqual(r.ok, false);
  assert.match(r.reason, /unknown_category/);
});

test('rejects candidate with empty category', () => {
  const r = _isAutoPublishWorthy(
    recruitmentCandidate({ suggestedCategory: '' }), NOW);
  assert.strictEqual(r.ok, false);
  assert.match(r.reason, /unknown_category/);
});

test('accepts every known JobCategory enum value', () => {
  for (const cat of [
    'ssc', 'banking', 'railway', 'upsc', 'statePsc',
    'teaching', 'defense', 'police',
  ]) {
    const r = _isAutoPublishWorthy(
      recruitmentCandidate({ suggestedCategory: cat }), NOW);
    assert.strictEqual(r.ok, true, `expected ${cat} accepted: ${r.reason}`);
  }
});

// ---------------------------------------------------------------------------
// Type-specific completeness — recruitment (the strict path)
// ---------------------------------------------------------------------------

test('happy path: complete recruitment candidate is worthy', () => {
  const r = _isAutoPublishWorthy(recruitmentCandidate(), NOW);
  assert.deepStrictEqual(r, { ok: true, reason: null });
});

test('rejects recruitment with no extractedFields', () => {
  const r = _isAutoPublishWorthy(
    recruitmentCandidate({ extractedFields: null }), NOW);
  assert.deepStrictEqual(r, { ok: false, reason: 'recruitment_no_extracted_fields' });
});

test('rejects recruitment missing endDate', () => {
  const c = recruitmentCandidate();
  c.extractedFields.applicationEndDate = null;
  const r = _isAutoPublishWorthy(c, NOW);
  assert.strictEqual(r.ok, false);
  assert.match(r.reason, /endDate/);
});

test('rejects recruitment missing fees', () => {
  const c = recruitmentCandidate();
  c.extractedFields.fees = {};
  const r = _isAutoPublishWorthy(c, NOW);
  assert.match(r.reason, /fees/);
});

test('rejects recruitment missing both age bounds', () => {
  const c = recruitmentCandidate();
  c.extractedFields.ageMin = null;
  c.extractedFields.ageMax = null;
  const r = _isAutoPublishWorthy(c, NOW);
  assert.match(r.reason, /age/);
});

test('accepts recruitment with only ageMin (max is optional)', () => {
  const c = recruitmentCandidate();
  c.extractedFields.ageMax = null;
  assert.strictEqual(_isAutoPublishWorthy(c, NOW).ok, true);
});

test('accepts recruitment with only ageMax', () => {
  const c = recruitmentCandidate();
  c.extractedFields.ageMin = null;
  assert.strictEqual(_isAutoPublishWorthy(c, NOW).ok, true);
});

test('rejects recruitment missing apply/official link (junk row)', () => {
  const c = recruitmentCandidate();
  c.extractedFields.links = [
    { label: 'Notification', url: 'https://ssc.gov.in/n.pdf', kind: 'notification' },
  ];
  const r = _isAutoPublishWorthy(c, NOW);
  assert.match(r.reason, /applyLink/);
});

test('lists ALL missing recruitment fields (admin can fix at once)', () => {
  const c = recruitmentCandidate();
  c.extractedFields.applicationEndDate = null;
  c.extractedFields.fees = {};
  c.extractedFields.ageMin = null;
  c.extractedFields.ageMax = null;
  const r = _isAutoPublishWorthy(c, NOW);
  // All three should appear in the reason for fast diagnostics.
  assert.match(r.reason, /endDate/);
  assert.match(r.reason, /fees/);
  assert.match(r.reason, /age/);
});

// ---------------------------------------------------------------------------
// Type-specific completeness — result / admitCard (lenient path)
// ---------------------------------------------------------------------------

test('happy path: result with typed link is worthy', () => {
  assert.strictEqual(_isAutoPublishWorthy(resultCandidate(), NOW).ok, true);
});

test('rejects result without a result-typed link', () => {
  const c = resultCandidate();
  c.extractedFields.links = [
    { label: 'Notification', url: 'https://x', kind: 'notification' },
  ];
  const r = _isAutoPublishWorthy(c, NOW);
  assert.strictEqual(r.ok, false);
  assert.match(r.reason, /result_missing_typed_link/);
});

test('happy path: admitCard with typed link is worthy', () => {
  assert.strictEqual(_isAutoPublishWorthy(admitCardCandidate(), NOW).ok, true);
});

test('rejects admitCard without admitCard-typed link', () => {
  const c = admitCardCandidate();
  c.extractedFields.links = [];
  const r = _isAutoPublishWorthy(c, NOW);
  assert.match(r.reason, /admitCard_missing_typed_link/);
});

test('rejects unknown type defensively', () => {
  const c = recruitmentCandidate({ type: 'something_new' });
  const r = _isAutoPublishWorthy(c, NOW);
  assert.match(r.reason, /^unknown_type/);
});

// ---------------------------------------------------------------------------
// Mapper: server-side counterpart to CandidateToJobAlertMapper
// ---------------------------------------------------------------------------

test('mapper: recruitment doc carries every published-form field', () => {
  const candidate = recruitmentCandidate();
  const doc = _buildJobAlertDocFromCandidate(candidate, 'cand_1', NOW);

  assert.strictEqual(doc.title, candidate.rawTitle);
  assert.strictEqual(doc.organization, 'SSC');
  assert.strictEqual(doc.category, 'ssc');
  assert.strictEqual(doc.type, 'recruitment');
  assert.strictEqual(doc.status, 'openForApplication');
  assert.strictEqual(doc.vacancies, 1865);
  assert.strictEqual(doc.ageLimit, '18–32 years');
  assert.strictEqual(doc.applicationFeeGeneralPaise, 100 * 100);
  assert.strictEqual(doc.applicationFeeReservedPaise, 0);
  assert.strictEqual(doc.isActive, true);
  assert.strictEqual(doc.priority, 5);
  assert.strictEqual(doc.sourceCandidateId, 'cand_1');
  assert.strictEqual(doc.createdBy, REVIEWER_TAG);
  assert.ok(doc.applicationEndDate instanceof StubTimestamp);
});

test('mapper: importantLinks ordered apply → notification → official → aggregator', () => {
  const candidate = recruitmentCandidate();
  const doc = _buildJobAlertDocFromCandidate(candidate, 'cand_1', NOW);
  const labels = doc.importantLinks.map((l) => l.label);
  // Apply URL is "ssc.gov.in/apply" and official is "ssc.gov.in" —
  // distinct, so the Official Website slot fires between Notification
  // and the aggregator source row.
  assert.deepStrictEqual(labels, [
    'Apply on Official Site',
    'Notification PDF',
    'Official Website',
    'Source (admin reference)',
  ]);
});

test('mapper: official link added when distinct from apply URL', () => {
  const candidate = recruitmentCandidate();
  // Apply and official are different above, so 4 entries total:
  // apply, notification, official, aggregator (syllabus is absent).
  const doc = _buildJobAlertDocFromCandidate(candidate, 'cand_1', NOW);
  const urls = doc.importantLinks.map((l) => l.url);
  assert.ok(urls.includes('https://ssc.gov.in/apply'));
  assert.ok(urls.includes('https://ssc.gov.in/n.pdf'));
  assert.ok(urls.includes('https://ssc.gov.in'));
  assert.ok(urls.includes(candidate.rawLink));
  assert.strictEqual(urls.length, 4);
});

test('mapper: official link skipped when same URL as apply (no dup)', () => {
  const candidate = recruitmentCandidate();
  candidate.extractedFields.links = [
    { label: 'Apply', url: 'https://ssc.gov.in', kind: 'apply' },
    { label: 'Official', url: 'https://ssc.gov.in', kind: 'official' },
  ];
  const doc = _buildJobAlertDocFromCandidate(candidate, 'cand_1', NOW);
  const ssccount = doc.importantLinks
    .filter((l) => l.url === 'https://ssc.gov.in').length;
  assert.strictEqual(ssccount, 1);
});

test('mapper: result doc gets resultDeclared status', () => {
  const doc = _buildJobAlertDocFromCandidate(resultCandidate(), 'r1', NOW);
  assert.strictEqual(doc.status, 'resultDeclared');
  assert.strictEqual(doc.type, 'result');
});

test('mapper: admitCard doc gets admitCardOut status', () => {
  const doc = _buildJobAlertDocFromCandidate(admitCardCandidate(), 'a1', NOW);
  assert.strictEqual(doc.status, 'admitCardOut');
  assert.strictEqual(doc.type, 'admitCard');
});

test('mapper: ageLimit handles min-only / max-only / both', () => {
  assert.strictEqual(_formatAgeRange(18, 32), '18–32 years');
  assert.strictEqual(_formatAgeRange(18, null), 'Min 18 years');
  assert.strictEqual(_formatAgeRange(null, 32), 'Max 32 years');
  assert.strictEqual(_formatAgeRange(null, null), null);
});

test('mapper: organization extraction prefers ALL-CAPS acronym', () => {
  assert.strictEqual(_inferOrganization('SSC CGL 2026 Notification'), 'SSC');
  assert.strictEqual(_inferOrganization('UPSC IAS 2026'), 'UPSC');
  // Compound acronym like "SSC / GD" is preserved.
  assert.strictEqual(
    _inferOrganization('SSC / GD Constable 2026'),
    'SSC / GD',
  );
  // No acronym → first 3 words.
  assert.strictEqual(
    _inferOrganization('Bihar Police Recruitment Drive 2026'),
    'Bihar Police Recruitment',
  );
});

test('mapper: general fee picks "General" bucket, not "Female General"', () => {
  assert.strictEqual(
    _generalFeeRupees({ 'General / OBC / EWS': 100, 'SC / ST': 0 }),
    100,
  );
  assert.strictEqual(
    _generalFeeRupees({ 'Female (General)': 50, 'General': 100 }),
    100,
  );
});

test('mapper: handles legacy candidate (no extractedFields)', () => {
  const candidate = {
    rawTitle: 'Legacy RSS Job Title',
    rawLink: 'https://example.com/job',
    suggestedCategory: 'ssc',
    suggestedApplyUrl: 'https://ssc.gov.in/apply',
    rawDescription: 'desc',
    type: 'recruitment',
  };
  const doc = _buildJobAlertDocFromCandidate(candidate, 'legacy', NOW);
  assert.strictEqual(doc.summary, 'desc');
  assert.strictEqual(doc.vacancies, null);
  assert.strictEqual(doc.ageLimit, null);
  assert.strictEqual(doc.applicationFeeGeneralPaise, null);
  assert.deepStrictEqual(doc.importantLinks, [
    { label: 'Apply on Official Site', url: 'https://ssc.gov.in/apply' },
    { label: 'Source (admin reference)', url: 'https://example.com/job' },
  ]);
});

test('mapper: stamps reviewer tag, not a real uid', () => {
  const doc = _buildJobAlertDocFromCandidate(
    recruitmentCandidate(), 'c1', NOW);
  assert.strictEqual(doc.createdBy, REVIEWER_TAG);
  assert.match(doc.createdBy, /^cron:auto-publish/);
});

test('safety: per-run cap is sane and not zero', () => {
  assert.ok(PER_RUN_CAP > 0 && PER_RUN_CAP <= 50,
    `cap ${PER_RUN_CAP} should be in (0, 50]`);
});

test('safety: freshness window is shorter than 1 week', () => {
  assert.ok(FRESH_HRS > 0 && FRESH_HRS <= 168,
    `freshness ${FRESH_HRS}h should be in (0, 168]`);
});

test('safety: title minimum is non-trivial', () => {
  assert.ok(MIN_TITLE >= 10, 'min title should be >= 10 chars');
});

test('safety: known categories cover all real JobCategory values except other', () => {
  const expected = [
    'ssc', 'banking', 'railway', 'upsc', 'statePsc',
    'teaching', 'defense', 'police',
  ];
  for (const c of expected) {
    assert.ok(KNOWN.has(c), `${c} should be in KNOWN`);
  }
  assert.ok(!KNOWN.has('other'), '"other" must NOT be auto-publishable');
});

// quick sanity for tiny helpers
test('helper: _hasLinkOfKind matches and rejects', () => {
  assert.ok(_hasLinkOfKind([{ kind: 'apply', url: 'x' }], ['apply']));
  assert.ok(!_hasLinkOfKind([{ kind: 'apply', url: '' }], ['apply']));
  assert.ok(!_hasLinkOfKind([{ kind: 'official', url: 'x' }], ['apply']));
  assert.ok(!_hasLinkOfKind(null, ['apply']));
});

test('helper: _statusForType maps every known type', () => {
  assert.strictEqual(_statusForType('recruitment'), 'openForApplication');
  assert.strictEqual(_statusForType('result'), 'resultDeclared');
  assert.strictEqual(_statusForType('admitCard'), 'admitCardOut');
  assert.strictEqual(_statusForType('garbage'), 'openForApplication');
});

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------

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

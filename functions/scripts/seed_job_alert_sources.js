/**
 * One-time idempotent seed for the `jobAlertSources` collection used by
 * `fetchJobAlertSources` / `fetchJobAlertSourcesNow` Cloud Functions.
 *
 * SAFE: Runs in DRY-RUN mode by default. Pass --apply to actually write.
 *
 * Usage:
 *   node scripts/seed_job_alert_sources.js          # dry-run (read-only)
 *   node scripts/seed_job_alert_sources.js --apply  # write/merge docs
 *
 * Re-running with --apply is safe: we upsert by stable doc id (sourceKey)
 * and only overwrite url / isActive / name — not runtime counters like
 * lastFetchedAt, itemsFoundLastRun.
 */

const { Firestore } = require('@google-cloud/firestore');
const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'academic-master';

/**
 * Canonical default sources. `active: false` means we know the feed is
 * unreliable or missing today — the doc is seeded so the admin can flip
 * it on later once a working URL is found, without a code change.
 *
 * Keep `sourceKey` stable: it's the Firestore document id, so re-runs
 * upsert instead of duplicating.
 */
const DEFAULT_SOURCES = [
  {
    sourceKey: 'free_job_alert',
    name: 'FreeJobAlert',
    url: 'https://www.freejobalert.com/feed/',
    active: true,
    notes: 'Aggregated latest govt jobs feed',
  },
  {
    sourceKey: 'jagran_josh_jobs',
    name: 'Jagran Josh – Jobs',
    url: 'https://www.jagranjosh.com/rss/jobs.xml',
    active: true,
    notes: 'Government jobs RSS from Jagran Josh',
  },
  {
    sourceKey: 'employment_news',
    name: 'Employment News',
    url: 'https://employmentnews.gov.in/',
    active: false,
    notes: 'Official site does not expose RSS. Keep disabled until a feed is available.',
  },
  {
    sourceKey: 'sarkari_result',
    name: 'SarkariResult',
    url: 'https://www.sarkariresult.com/',
    active: false,
    notes: 'No RSS; would need HTML scraping. Disabled by default.',
  },
];

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
  const clientId = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
  const clientSecret = 'j9iVZfS8kkCEFUPaAeJV0sAi';
  const oauth2Client = new OAuth2Client(clientId, clientSecret);
  oauth2Client.setCredentials({ refresh_token: refreshToken });
  return oauth2Client;
}

async function main() {
  const applyChanges = process.argv.includes('--apply');
  const authClient = createCredentials();
  const db = new Firestore({ projectId: PROJECT_ID, authClient });

  console.log('\n=== Seed Job Alert Sources ===');
  console.log('Mode: ' + (applyChanges ? 'APPLY (will write)' : 'DRY-RUN (read-only)'));
  console.log('Project: ' + PROJECT_ID + '\n');

  const plan = [];
  for (const src of DEFAULT_SOURCES) {
    const ref = db.collection('jobAlertSources').doc(src.sourceKey);
    const snap = await ref.get();
    plan.push({
      ref,
      sourceKey: src.sourceKey,
      action: snap.exists ? 'update' : 'create',
      desired: src,
      existing: snap.exists ? snap.data() : null,
    });
  }

  console.log('Planned changes:');
  console.log('-'.repeat(100));
  for (const p of plan) {
    console.log(
      '  ' + p.action.toUpperCase().padEnd(7) +
      ' | ' + p.sourceKey.padEnd(22) +
      ' | active=' + String(p.desired.active).padEnd(5) +
      ' | ' + p.desired.url
    );
  }
  console.log('-'.repeat(100) + '\n');

  if (!applyChanges) {
    console.log('DRY-RUN complete. No changes made.');
    console.log('To apply: node scripts/seed_job_alert_sources.js --apply\n');
    process.exit(0);
  }

  const now = Firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  for (const p of plan) {
    const { desired, ref, action } = p;
    const payload = {
      name: desired.name,
      url: desired.url,
      isActive: desired.active,
      notes: desired.notes,
      updatedAt: now,
    };
    if (action === 'create') {
      payload.createdAt = now;
      payload.lastFetchedAt = null;
      payload.lastFetchStatus = null;
      payload.lastError = null;
      payload.itemsFoundLastRun = 0;
      batch.set(ref, payload);
    } else {
      // Preserve runtime counters — only update config fields.
      batch.update(ref, payload);
    }
  }

  await batch.commit();
  console.log('Seeded ' + plan.length + ' sources.');
  console.log('Verify at: https://console.firebase.google.com/project/' + PROJECT_ID + '/firestore/data/~2FjobAlertSources\n');
  process.exit(0);
}

main().catch((err) => {
  console.error('Error:', err.message || err);
  process.exit(1);
});

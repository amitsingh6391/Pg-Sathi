/**
 * One-time script to fix memberships incorrectly marked as 'expired'.
 *
 * SAFE: Runs in DRY-RUN mode by default. Pass --apply to actually write.
 *
 * Usage:
 *   node fix_expired_memberships.js          # dry-run (read-only)
 *   node fix_expired_memberships.js --apply  # actually fix the data
 */

const { Firestore } = require('@google-cloud/firestore');
const { OAuth2Client } = require('google-auth-library');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'academic-master';

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
  const applyFix = process.argv.includes('--apply');
  const authClient = createCredentials();
  const db = new Firestore({ projectId: PROJECT_ID, authClient });

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  console.log('\n=== Fix Incorrectly Expired Memberships ===');
  console.log('Mode: ' + (applyFix ? 'APPLY (will write)' : 'DRY-RUN (read-only)'));
  console.log('Project: ' + PROJECT_ID);
  console.log('Today: ' + today.toISOString().split('T')[0] + '\n');

  const snapshot = await db.collection('memberships')
    .where('status', '==', 'expired')
    .get();

  console.log('Total expired memberships in Firestore: ' + snapshot.size + '\n');

  const wronglyExpired = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const endDate = data.endDate && data.endDate.toDate ? data.endDate.toDate() : null;
    if (!endDate) continue;

    const endDateOnly = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());

    if (!(today > endDateOnly)) {
      wronglyExpired.push({
        id: doc.id,
        ref: doc.ref,
        studentName: data.studentName || null,
        phoneNumber: data.phoneNumber || 'Unknown',
        seatId: data.assignedSeatId || 'N/A',
        endDate: endDate.toISOString().split('T')[0],
        paymentStatus: data.paymentStatus || '?',
      });
    }
  }

  if (wronglyExpired.length === 0) {
    console.log('No incorrectly expired memberships found. Nothing to fix!');
    process.exit(0);
  }

  console.log('Found ' + wronglyExpired.length + ' memberships incorrectly marked as expired:\n');
  console.log('-'.repeat(100));
  for (const m of wronglyExpired) {
    const name = (m.studentName || m.phoneNumber).substring(0, 20);
    console.log('  ' + name.padEnd(22) + ' | Seat: ' + m.seatId.padEnd(5) + ' | End: ' + m.endDate + ' | Pay: ' + m.paymentStatus.padEnd(12) + ' | ' + m.id);
  }
  console.log('-'.repeat(100));
  console.log('\nAction: status expired -> active for ' + wronglyExpired.length + ' memberships');

  if (!applyFix) {
    console.log('\nDRY-RUN complete. No changes made.');
    console.log('To apply: node scripts/fix_expired_memberships.js --apply\n');
    process.exit(0);
  }

  console.log('\nApplying fix...');
  let fixed = 0;
  for (let i = 0; i < wronglyExpired.length; i += 500) {
    const batch = db.batch();
    const chunk = wronglyExpired.slice(i, i + 500);
    for (const m of chunk) {
      batch.update(m.ref, { status: 'active' });
    }
    await batch.commit();
    fixed += chunk.length;
    console.log('  Batch ' + Math.ceil((i+1)/500) + ': ' + chunk.length + ' memberships restored');
  }
  console.log('\nDone! ' + fixed + ' memberships restored to active.\n');
  process.exit(0);
}

main().catch(function(err) {
  console.error('Error:', err.message || err);
  process.exit(1);
});

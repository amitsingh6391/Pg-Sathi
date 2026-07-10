# DNS Configuration for librarytrack.in → Firebase Hosting

## Steps to Configure DNS in Hostinger

### 1. Remove Old A Record
- **Type**: A
- **Name**: @ (or librarytrack.in)
- **Points to**: 84.32.84.32
- **Action**: DELETE this record

### 2. Add New A Record for Firebase
- **Type**: A
- **Name**: @ (or librarytrack.in)
- **Points to**: 199.36.158.100
- **TTL**: 14400 (or default)
- **Action**: ADD this record

### 3. Add TXT Record for Verification
- **Type**: TXT
- **Name**: @ (or librarytrack.in)
- **Value**: hosting-site=academic-master
- **TTL**: 300 (or default)
- **Action**: ADD this record

### 4. Keep Existing Records (DO NOT DELETE)
Keep these CNAME records for email:
- `hostingermail-c._domainkey` → `hostingermail-c.dkim.mail.hostinger.com`
- `hostingermail-b._domainkey` → `hostingermail-b.dkim.mail.hostinger.com`
- `hostingermail-a._domainkey` → `hostingermail-a.dkim.mail.hostinger.com`
- `www` → `librarytrack.in`
- `autodiscover` → `autodiscover.mail.h...` (keep as is)

## Summary of Changes

**DELETE:**
- A record: @ → 84.32.84.32

**ADD:**
- A record: @ → 199.36.158.100
- TXT record: @ → hosting-site=academic-master

**KEEP:**
- All CNAME records (for email functionality)

## After DNS Configuration

1. Wait for DNS propagation (usually 5-60 minutes, can take up to 48 hours)
2. Firebase will automatically verify the domain
3. Firebase will provision SSL certificate automatically (takes a few minutes to hours)
4. Your site will be live at: https://librarytrack.in

## Verification

After DNS changes:
- Check DNS propagation: https://dnschecker.org/#A/librarytrack.in
- Verify in Firebase Console: Hosting → Custom domains
- Test the site: https://librarytrack.in


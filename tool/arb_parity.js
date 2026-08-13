// Checks that app_en.arb and app_ar.arb expose exactly the same message keys.
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '..', 'lib', 'l10n');
const read = (f) => JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
const messageKeys = (obj) =>
  Object.keys(obj).filter((k) => !k.startsWith('@'));

const en = read('app_en.arb');
const ar = read('app_ar.arb');
const enKeys = messageKeys(en);
const arKeys = messageKeys(ar);
const enSet = new Set(enKeys);
const arSet = new Set(arKeys);

const missingInAr = enKeys.filter((k) => !arSet.has(k));
const missingInEn = arKeys.filter((k) => !enSet.has(k));
const untranslated = enKeys.filter((k) => arSet.has(k) && ar[k] === en[k]);

console.log('en keys:', enKeys.length);
console.log('ar keys:', arKeys.length);
console.log('missing in ar:', missingInAr.length, missingInAr.join(', '));
console.log('missing in en:', missingInEn.length, missingInEn.join(', '));
console.log('identical en/ar values:', untranslated.length);
if (process.argv.includes('--list-identical')) {
  untranslated.forEach((k) => console.log('  =', k, JSON.stringify(en[k])));
}

if (missingInAr.length || missingInEn.length) {
  console.error('PARITY FAIL');
  process.exit(1);
}
console.log('PARITY OK');

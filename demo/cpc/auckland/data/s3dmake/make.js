// make.js s3dmake.html cut.txt.gz OUT.DAT [name]: tools/s3dmake's converter run by node (the tests)
const fs = require('fs'), zlib = require('zlib');
const html = fs.readFileSync(process.argv[2], 'utf8');
const js = html.split('<script>')[1].split('</script>')[0];
const m = { exports: {} }; new Function('module', js)(m);
(async () => {
  const text = zlib.gunzipSync(fs.readFileSync(process.argv[3])).toString('utf8');
  const out = await m.exports.make(text, { name: process.argv[5] || 'AUCKLAND', kb: 3968 }, async (s) => console.log(s));
  fs.writeFileSync(process.argv[4], Buffer.from(out));
})().catch((e) => { console.error(e); process.exit(1); });

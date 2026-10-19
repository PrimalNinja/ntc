// make.js s3dmake.html cut.txt.gz OUT.DAT [name [kb [start street [area place [km [masks]]]]]]: tools/s3dmake's converter run by node (the tests)
const fs = require('fs'), zlib = require('zlib');
const html = fs.readFileSync(process.argv[2], 'utf8');
const js = html.split('<script>')[1].split('</script>')[0];
const m = { exports: {} }; new Function('module', js)(m);
(async () => {
  const text = zlib.gunzipSync(fs.readFileSync(process.argv[3])).toString('utf8');
  const out = await m.exports.make(text, { name: process.argv[5] || 'AUCKLAND', kb: +(process.argv[6] || 3968), start: process.argv[7] || '', area: process.argv[8] || '', areakm: +(process.argv[9] || 3), masks: process.argv[10] === 'masks' }, async (s) => console.log(s));
  fs.writeFileSync(process.argv[4], Buffer.from(out));
})().catch((e) => { console.error(e); process.exit(1); });

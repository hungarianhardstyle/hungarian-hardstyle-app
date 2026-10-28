import fs from 'node:fs';
const p = 'tmp/plugin-2154/huhs-mobile-api/includes/push.php';
let t = fs.readFileSync(p, 'utf8');
const note = '\n    // 2.14.23: determinisztikus sorrend. A token-tar (WordPress option) sorrendje\n    // valtozhat (ujraregisztralas, token-csere), es akkor ugyanaz a token KET\n    // szeletbe esett -> egy korbol tobb ertesites ment ki ugyanarra az eszkozre.\n    // A kulcs szerinti rendezes stabil, ezert az offset jelentese allando.\n    ksort($recipients);';
const targets = [
  '    $recipients = huhs_push_recipients($tokens, $data, $language);',
  '    $recipients = huhs_push_recipients(is_array($tokens) ? $tokens : array(), $data);',
];
let changed = 0;
for (const line of targets) {
  if (!t.includes(line)) { console.log('NEM talalt:', line.slice(0, 40)); continue; }
  t = t.replace(line, line + note);
  changed += 1;
}
if (changed) fs.writeFileSync(p, t, 'utf8');
console.log('módosított helyek:', changed);

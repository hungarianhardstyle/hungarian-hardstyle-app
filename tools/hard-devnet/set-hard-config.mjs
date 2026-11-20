// A `hard_config/current` dokumentum beállítása az ÉLES adatbázisban (devnet-mint).
//
// Futtatás:  node tools/hard-devnet/set-hard-config.mjs <mint-cím> [--disable]
//
// Alapból bekapcsolja a funkciót (enabled=true, cluster=devnet). `--disable`
// kikapcsolja. Mainnet szándékosan nem engedélyezett (külön döntés).
import { firestoreGet, firestoreSet } from '../lib/live-firebase.mjs';

const mint = process.argv[2];
const disable = process.argv.includes('--disable');
if (!mint || !/^[1-9A-HJ-NP-Za-km-z]{32,44}$/.test(mint)) {
  console.error('Használat: node tools/hard-devnet/set-hard-config.mjs <mint-cím> [--disable]');
  process.exit(2);
}

await firestoreSet('hard_config/current', { enabled: !disable, mint, cluster: 'devnet' }, { merge: true });
const saved = await firestoreGet('hard_config/current');
console.log(JSON.stringify(saved, null, 2));

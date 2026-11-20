// A `hard_config/current` dokumentum beállítása az ÉLES adatbázisban (devnet-mint).
//
// Futtatás:  node tools/hard-devnet/set-hard-config.mjs <mint-cím> [--disable] [--confirm]
//
// `--confirm` NÉLKÜL csak kiírja, mit írna (szárazon fut). Az `--confirm` ír az
// éles adatbázisba — a `tools/lib/live-firebase.mjs` fejlécének szabálya szerint
// az éles írás csak kifejezett megerősítéssel történhet.
// Alapból bekapcsolja a funkciót (enabled=true, cluster=devnet); `--disable`
// kikapcsolja. Mainnet szándékosan nem engedélyezett (külön döntés).
import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { firestoreGet, firestoreSet } from '../lib/live-firebase.mjs';

// A cím-ellenőrzés ugyanaz, mint a backendben (pontosan 32 bájtos base58).
const { parseSolanaAddress } = createRequire(import.meta.url)('../../functions/hard-wallet-plan.js');

export const isValidMint = (value) => parseSolanaAddress(value) !== null;

async function main() {
  const mint = process.argv[2];
  if (!isValidMint(mint)) {
    console.error('Használat: node tools/hard-devnet/set-hard-config.mjs <mint-cím> [--disable] [--confirm]');
    process.exit(2);
  }
  const fields = { enabled: !process.argv.includes('--disable'), mint, cluster: 'devnet' };
  if (!process.argv.includes('--confirm')) {
    console.log('SZÁRAZ FUTÁS (nem ír). Ezt írná a hard_config/current dokumentumba:');
    console.log(JSON.stringify(fields, null, 2));
    console.log('Az éles íráshoz add meg az --confirm kapcsolót.');
    return;
  }
  await firestoreSet('hard_config/current', fields, { merge: true });
  console.log(JSON.stringify(await firestoreGet('hard_config/current'), null, 2));
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();

// HARD token – DEVNET mint létrehozása és ellenőrzése.
//
// Futtatás:  node hard-devnet-token.mjs            (létrehoz, majd ellenőriz)
//            node hard-devnet-token.mjs --verify   (csak a meglévő mintet ellenőrzi)
//
// BIZTONSÁG: csak devnet. A kulcsok a repón KÍVÜL vannak (~/.huhs-hard/), soha nem
// kerülnek a repóba és nem íródnak ki. Mainnetre ez a szkript SZÁNDÉKOSAN nem fut.
import { Connection, Keypair, LAMPORTS_PER_SOL, PublicKey } from '@solana/web3.js';
import {
  AuthorityType,
  createMint,
  getMint,
  getOrCreateAssociatedTokenAccount,
  mintTo,
  setAuthority,
} from '@solana/spl-token';
import {
  createMetadataAccountV3,
  fetchMetadata,
  findMetadataPda,
  mplTokenMetadata,
} from '@metaplex-foundation/mpl-token-metadata';
import { createSignerFromKeypair, keypairIdentity, none, publicKey as umiPublicKey } from '@metaplex-foundation/umi';
import { createUmi } from '@metaplex-foundation/umi-bundle-defaults';
import { fromWeb3JsKeypair } from '@metaplex-foundation/umi-web3js-adapters';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export const DECIMALS = 6;
export const TOTAL_SUPPLY_WHOLE = 100_000_000n;
export const EXPECTED_RAW_SUPPLY = TOTAL_SUPPLY_WHOLE * 10n ** BigInt(DECIMALS);

// A név legfeljebb 32, a szimbólum legfeljebb 10 karakter lehet (Metaplex-korlát).
export const TOKEN_NAME = 'HUHS';
export const TOKEN_SYMBOL = 'HARD';
// A tárcák a logót ebből a JSON-ból olvassák (a lánc csak az URL-t tárolja).
export const TOKEN_URI = 'https://hardtoken.hungarianhardstyle.hu/token.json';

/** A névadás lánc-szintű ellenőrzése: név, szimbólum, és hogy már nem módosítható. */
export function verifyMetadataFacts({ name, symbol, isMutable, uri }) {
  const problems = [];
  if (name !== TOKEN_NAME) problems.push(`név="${name}", várt: "${TOKEN_NAME}"`);
  if (symbol !== TOKEN_SYMBOL) problems.push(`szimbólum="${symbol}", várt: "${TOKEN_SYMBOL}"`);
  if (uri !== undefined && uri !== TOKEN_URI) problems.push(`uri="${uri}", várt: "${TOKEN_URI}"`);
  if (isMutable !== false) problems.push('a metaadat MÓDOSÍTHATÓ (át lehetne nevezni)');
  return { ok: problems.length === 0, problems };
}

/** A rug pull elleni lánc-szintű garanciák tiszta ellenőrzése (tesztelhető). */
export function verifyMintFacts({ supply, decimals, mintAuthority, freezeAuthority }) {
  const problems = [];
  if (decimals !== DECIMALS) problems.push(`decimals=${decimals}, várt: ${DECIMALS}`);
  if (BigInt(supply) !== EXPECTED_RAW_SUPPLY) {
    problems.push(`supply=${supply}, várt: ${EXPECTED_RAW_SUPPLY}`);
  }
  if (mintAuthority !== null) problems.push('a mint authority NINCS visszavonva');
  if (freezeAuthority !== null) problems.push('a freeze authority NINCS visszavonva');
  return { ok: problems.length === 0, problems };
}

const isMain = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) await main();

async function main() {
  const dir = path.join(os.homedir(), '.huhs-hard');
  const keyFile = path.join(dir, 'devnet-authority.json');
  const mintFile = path.join(dir, 'devnet-mint.json');
  const verifyOnly = process.argv.includes('--verify');
  fs.mkdirSync(dir, { recursive: true });

  const connection = new Connection('https://api.devnet.solana.com', 'confirmed');

  // `--new`: a régi (névtelen) devnet-mint félretétele, hogy újat lehessen hozni.
  if (process.argv.includes('--new') && fs.existsSync(mintFile)) {
    fs.renameSync(mintFile, path.join(dir, `devnet-mint.old-${Date.now()}.json`));
  }

  if (!verifyOnly) {
    if (fs.existsSync(mintFile)) {
      console.log('Már van devnet mint (', mintFile, ') – csak ellenőrzöm.');
    } else {
      let payer;
      if (fs.existsSync(keyFile)) {
        payer = Keypair.fromSecretKey(Uint8Array.from(JSON.parse(fs.readFileSync(keyFile, 'utf8'))));
      } else {
        payer = Keypair.generate();
        fs.writeFileSync(keyFile, JSON.stringify(Array.from(payer.secretKey)), { mode: 0o600 });
        console.log('Új devnet kulcs létrehozva a repón kívül:', keyFile);
      }
      console.log('Devnet tulajdonos-cím:', payer.publicKey.toBase58());

      const balance = await connection.getBalance(payer.publicKey);
      if (balance < 0.05 * LAMPORTS_PER_SOL) {
        console.log('Devnet SOL kérése (airdrop)…');
        try {
          const sig = await connection.requestAirdrop(payer.publicKey, 1 * LAMPORTS_PER_SOL);
          const latest = await connection.getLatestBlockhash();
          await connection.confirmTransaction({ signature: sig, ...latest }, 'confirmed');
        } catch {
          // Az RPC-faucet gyakran zárva van (410) – ilyenkor a webes faucet kell.
          console.error(
            `Az RPC-faucet nem ad SOL-t. Kérj devnet SOL-t kézzel: https://faucet.solana.com\n` +
              `Cím: ${payer.publicKey.toBase58()}\nAztán futtasd újra ezt a szkriptet.`,
          );
          process.exit(3);
        }
      }

      // Kincstár: devnetben a saját cím; élesben többaláírású tárca lesz.
      const mint = await createMint(connection, payer, payer.publicKey, payer.publicKey, DECIMALS);
      // A névadásnak a jogok visszavonása ELŐTT kell megtörténnie (a mint authority
      // aláírása kell hozzá). `isMutable: false`: utána sem lehet átnevezni.
      const umi = createUmi('https://api.devnet.solana.com').use(mplTokenMetadata());
      const signer = createSignerFromKeypair(umi, fromWeb3JsKeypair(payer));
      umi.use(keypairIdentity(signer));
      await createMetadataAccountV3(umi, {
        mint: umiPublicKey(mint.toBase58()),
        mintAuthority: signer,
        updateAuthority: signer.publicKey,
        data: {
          name: TOKEN_NAME,
          symbol: TOKEN_SYMBOL,
          uri: TOKEN_URI,
          sellerFeeBasisPoints: 0,
          creators: none(),
          collection: none(),
          uses: none(),
        },
        isMutable: false,
        collectionDetails: none(),
      }).sendAndConfirm(umi);
      const treasury = await getOrCreateAssociatedTokenAccount(connection, payer, mint, payer.publicKey);
      await mintTo(connection, payer, mint, treasury.address, payer, EXPECTED_RAW_SUPPLY);
      // A fix kínálat garanciája: mindkét jogosultság visszavonása.
      await setAuthority(connection, payer, mint, payer, AuthorityType.MintTokens, null);
      await setAuthority(connection, payer, mint, payer, AuthorityType.FreezeAccount, null);

      fs.writeFileSync(
        mintFile,
        JSON.stringify({ mint: mint.toBase58(), treasury: treasury.address.toBase58(), cluster: 'devnet' }, null, 2),
      );
      console.log('Mint létrehozva:', mint.toBase58());
    }
  }

  if (!fs.existsSync(mintFile)) {
    console.error('Nincs devnet mint – futtasd paraméter nélkül.');
    process.exit(2);
  }
  const { mint, treasury } = JSON.parse(fs.readFileSync(mintFile, 'utf8'));
  const info = await getMint(connection, new PublicKey(mint));
  const result = verifyMintFacts({
    supply: info.supply,
    decimals: info.decimals,
    mintAuthority: info.mintAuthority ? info.mintAuthority.toBase58() : null,
    freezeAuthority: info.freezeAuthority ? info.freezeAuthority.toBase58() : null,
  });
  console.log(JSON.stringify({ mint, treasury, supply: String(info.supply), decimals: info.decimals,
    mintAuthority: info.mintAuthority?.toBase58() ?? null,
    freezeAuthority: info.freezeAuthority?.toBase58() ?? null }, null, 2));
  const problems = [...result.problems];
  try {
    const umi = createUmi('https://api.devnet.solana.com').use(mplTokenMetadata());
    const meta = await fetchMetadata(umi, findMetadataPda(umi, { mint: umiPublicKey(mint) }));
    const named = verifyMetadataFacts({ name: meta.name, symbol: meta.symbol, isMutable: meta.isMutable, uri: meta.uri });
    console.log(JSON.stringify({ name: meta.name, symbol: meta.symbol, uri: meta.uri, isMutable: meta.isMutable }));
    problems.push(...named.problems);
  } catch {
    problems.push('a mintnek nincs metaadata-fiókja (nincs neve)');
  }
  if (problems.length) {
    console.error('HIBA:', problems.join('; '));
    process.exit(1);
  }
  console.log('RENDBEN: fix kínálat, név beállítva és zárolva, a mint és a freeze authority visszavonva (devnet).');
}

/**
 * Verification for the chunked push delivery logic in
 * .tmp-api-24110/huhs-mobile-api/includes/push.php
 *
 * PHP is not installed on this machine, so the delivery algorithm (recipient
 * filtering, time-budgeted slicing, offset continuation, dead-token pruning) is
 * mirrored here and checked for the properties that matter:
 *   - every eligible device is sent to exactly once
 *   - ineligible devices are never sent to
 *   - the continuation chain always terminates
 *   - dead tokens are pruned, live ones are kept
 *
 * Usage: node .tmp-phpcheck/simulate-push.mjs
 */

const BUDGET = 15;
const MAX_RUNS = 40;

const makeTokens = (count) => {
  const tokens = {};
  for (let i = 0; i < count; i += 1) tokens[`key${String(i).padStart(4, '0')}`] = { token: `tok${i}`, enabled: true };
  return tokens;
};

// --- mirror of huhs_push_recipients -----------------------------------------
const recipients = (tokens, data) => {
  const type = data.type ?? 'custom';
  const out = {};
  for (const [key, record] of Object.entries(tokens)) {
    if (typeof record !== 'object' || record === null) continue;
    const token = String(record.token ?? '');
    if (token === '') continue;
    if ('enabled' in record && !record.enabled) continue;
    if (type === 'news' && 'news' in record && !record.news) continue;
    if (type === 'event' && 'events' in record && !record.events) continue;
    if (type === 'release' && 'releases' in record && !record.releases) continue;
    if (data.kind && 'reminders' in record && !record.reminders) continue;
    out[key] = token;
  }
  return out;
};

// --- mirror of huhs_push_deliver_slice --------------------------------------
const deliverSlice = (list, clock, attempt) => {
  let sent = 0;
  let processed = 0;
  const dead = [];
  const deadline = clock.now + BUDGET;
  const entries = Object.entries(list);
  for (const [key, token] of entries) {
    if (processed > 0 && clock.now >= deadline) break;
    const outcome = attempt(key, token);
    clock.now += clock.latency;
    processed += 1;
    if (outcome === 'sent') sent += 1;
    else if (outcome === 'dead') dead.push(key);
  }
  return { sent, processed, dead, remaining: entries.length - processed };
};

// --- mirror of huhs_push_send + huhs_push_continue --------------------------
const runBroadcast = (tokens, data, clock, attempt) => {
  const log = { attempted: [], runs: 0, pruned: [], jobs: 0 };
  const prune = (keys) => {
    for (const key of new Set(keys)) {
      if (key in tokens) {
        delete tokens[key];
        log.pruned.push(key);
      }
    }
  };

  let result = deliverSlice(recipients(tokens, data), clock, attempt);
  log.runs += 1;
  log.attempted.push(...[]);
  if (result.remaining > 0) {
    let job = {
      offset: result.processed,
      dead: result.dead,
      runs: 1,
    };
    log.jobs += 1;
    // continuation chain: each pass is one scheduled follow-up run
    for (;;) {
      if (job.runs > MAX_RUNS) return { log, stoppedEarly: true };
      const list = recipients(tokens, data);
      const keys = Object.keys(list);
      const remainingKeys = keys.slice(job.offset);
      const slice = {};
      for (const key of remainingKeys) slice[key] = list[key];

      const pass = deliverSlice(slice, clock, attempt);
      log.runs += 1;
      const dead = [...job.dead, ...pass.dead];

      if (pass.remaining > 0) {
        job = { offset: job.offset + pass.processed, dead, runs: job.runs + 1 };
        continue;
      }
      prune(dead);
      return { log, stoppedEarly: false };
    }
  }
  prune(result.dead);
  return { log, stoppedEarly: false };
};

const check = (name, condition, detail) => {
  console.log(`${condition ? 'OK   ' : 'HIBA '} ${name}${condition ? '' : ` — ${detail}`}`);
  return condition ? 0 : 1;
};

let failures = 0;

// 1. Everyone eligible gets exactly one send, nobody twice.
{
  const tokens = makeTokens(895);
  // 300 of them are stale and FCM answers UNREGISTERED
  const deadKeys = new Set(Object.keys(tokens).filter((k, i) => i % 3 === 0));
  const seen = [];
  const clock = { now: 0, latency: 0.2 };
  const { log, stoppedEarly } = runBroadcast(tokens, { type: 'news' }, clock, (key) => {
    seen.push(key);
    return deadKeys.has(key) ? 'dead' : 'sent';
  });
  const unique = new Set(seen);
  failures += check('895 eszköz: mindenki pontosan egyszer kap értesítést', seen.length === 895 && unique.size === 895, `sent=${seen.length} unique=${unique.size}`);
  failures += check('a lánc befejeződött, nem futott bele a biztonsági plafonba', stoppedEarly === false, `runs=${log.runs}`);
  failures += check('a halott tokenek törlődtek a listából', Object.keys(tokens).length === 895 - deadKeys.size, `maradek=${Object.keys(tokens).length}`);
  failures += check('egyetlen élő token sem törlődött', Object.keys(tokens).every((k) => !deadKeys.has(k)), 'elotoken torolve');
  const expectedRuns = Math.ceil(895 / Math.floor(BUDGET / clock.latency));
  console.log(`     (körök: ${log.runs}, várt kb. ${expectedRuns}, 1 kör alatt ~${Math.floor(BUDGET / clock.latency)} eszköz)`);
}

// 2. A single-run broadcast (few devices) does not create a job at all.
{
  const tokens = makeTokens(10);
  const clock = { now: 0, latency: 0.2 };
  let sends = 0;
  const { log } = runBroadcast(tokens, { type: 'news' }, clock, () => {
    sends += 1;
    return 'sent';
  });
  failures += check('kevés eszköznél nincs folytatás (1 kör)', log.runs === 1 && sends === 10, `runs=${log.runs} sends=${sends}`);
}

// 3. Preference filtering is unchanged: only opted-in devices are contacted.
{
  const tokens = makeTokens(50);
  Object.keys(tokens).forEach((k, i) => {
    tokens[k].news = i % 2 === 0;
  });
  const clock = { now: 0, latency: 0.2 };
  const seen = [];
  runBroadcast(tokens, { type: 'news' }, clock, (key) => {
    seen.push(key);
    return 'sent';
  });
  failures += check('a hír-preferencia szerint szűr (25 igen / 25 nem)', seen.length === 25, `sent=${seen.length}`);
  failures += check('csak a bekapcsolt eszközök kaptak értesítést', seen.every((k, i) => tokens[k] === undefined || true) && seen.every((k) => Number(k.slice(3)) % 2 === 0), seen.join(','));
}

// 4. A run that can only do one device per pass still finishes and terminates.
{
  const tokens = makeTokens(40);
  const clock = { now: 0, latency: 20 }; // each send blows the whole budget
  const seen = [];
  const { log, stoppedEarly } = runBroadcast(tokens, { type: 'news' }, clock, (key) => {
    seen.push(key);
    return 'sent';
  });
  failures += check('1 eszköz / kör esetén is mindenki megkapja', seen.length === 40 && new Set(seen).size === 40, `sent=${seen.length}`);
  failures += check('a lánc így is megáll (nincs végtelen ciklus)', stoppedEarly === false && log.runs === 40, `runs=${log.runs}`);
}

// 5. A failed send is still progress, so the chain must run to the end and
//    must not delete anything.
{
  const tokens = makeTokens(500);
  const clock = { now: 0, latency: 0.2 };
  const { log, stoppedEarly } = runBroadcast(tokens, { type: 'news' }, clock, () => 'failed');
  failures += check('tartós FCM-hiba esetén is végigfut a lánc', stoppedEarly === false && log.runs === Math.ceil(500 / 75), `runs=${log.runs}`);
  failures += check('hibánál nem törlünk élő tokent', Object.keys(tokens).length === 500, `maradek=${Object.keys(tokens).length}`);
}

// 6. The run cap is the real safety rail: a pathologically slow delivery must
//    give up instead of looping forever.
{
  const tokens = makeTokens(5000);
  const clock = { now: 0, latency: 20 }; // one device per run
  const { log, stoppedEarly } = runBroadcast(tokens, { type: 'news' }, clock, () => 'sent');
  failures += check('kórosan lassú kézbesítésnél a plafon megállítja a láncot', stoppedEarly === true && log.runs > MAX_RUNS, `runs=${log.runs}`);
}

console.log(failures === 0 ? '\nMinden ellenőrzés sikeres.' : `\n${failures} ellenőrzés hibás.`);
process.exit(failures === 0 ? 0 : 1);

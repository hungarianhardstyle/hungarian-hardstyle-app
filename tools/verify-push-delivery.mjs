/**
 * Verification for the chunked push delivery logic in
 * .tmp-api-24115/huhs-mobile-api/includes/push.php
 *
 * PHP is not installed on this machine, so the delivery algorithm is mirrored
 * here and checked for the properties that matter:
 *   - every eligible device is sent to exactly once
 *   - ineligible devices are never sent to
 *   - the offset continuation is always a real prefix of the recipient list
 *   - the continuation chain always terminates
 *   - dead tokens are pruned, live ones are kept
 *   - the parallel path falls back to the serial one when it cannot reach FCM
 *   - a news notification is never silently lost, and never sent twice
 *
 * Usage: node tools/verify-push-delivery.mjs
 */

const BUDGET = 15;        // HUHS_PUSH_TIME_BUDGET
const MAX_RUNS = 40;      // HUHS_PUSH_MAX_RUNS
const CONCURRENCY = 15;   // HUHS_PUSH_CONCURRENCY
const NEWS_MAX_ATTEMPTS = 3; // HUHS_PUSH_NEWS_MAX_ATTEMPTS

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

/** Mirrors the outcome classification: 'sent' | 'dead' | 'failed' | 'transport'. */
const tally = (outcome, counters) => {
  if (outcome === 'sent') counters.sent += 1;
  else if (outcome === 'dead') counters.dead.push(counters.currentKey);
  else {
    counters.failed += 1;
    if (outcome === 'transport') counters.transport += 1;
  }
};

// --- mirror of huhs_push_deliver_serial (the fallback path) -----------------
const deliverSliceSerial = (list, clock, attempt, concurrency = 1) => {
  const entries = Object.entries(list);
  const counters = { sent: 0, failed: 0, transport: 0, dead: [], currentKey: '' };
  let processed = 0;
  const deadline = clock.now + BUDGET;
  for (const [key, token] of entries) {
    if (processed > 0 && clock.now >= deadline) break;
    counters.currentKey = key;
    tally(attempt(key, token), counters);
    clock.now += clock.latency;
    processed += 1;
  }
  void concurrency;
  return { ...counters, processed, remaining: entries.length - processed };
};

// --- mirror of huhs_push_deliver_parallel ----------------------------------
// A batch is in flight together, so a batch costs ONE latency, not one per
// device, and the processed count always stays a prefix of the list.
const deliverSliceParallel = (list, clock, attempt, concurrency = CONCURRENCY) => {
  const entries = Object.entries(list);
  const counters = { sent: 0, failed: 0, transport: 0, dead: [], currentKey: '' };
  let processed = 0;
  const deadline = clock.now + BUDGET;
  while (processed < entries.length) {
    if (processed > 0 && clock.now >= deadline) break;
    const batch = entries.slice(processed, processed + concurrency);
    for (const [key, token] of batch) {
      counters.currentKey = key;
      tally(attempt(key, token), counters);
    }
    clock.now += clock.latency;
    processed += batch.length;
  }
  return { ...counters, processed, remaining: entries.length - processed };
};

// --- mirror of huhs_push_deliver_slice (the dispatcher) --------------------
const deliverSlice = (list, clock, attempt) => {
  const result = deliverSliceParallel(list, clock, attempt);
  // Fall back to the proven serial path when nothing could even be attempted
  // over the network. Worst case is then today's behaviour, not worse.
  if (result.sent === 0 && result.transport > 0 && result.failed === result.processed) {
    return deliverSliceSerial(list, clock, attempt);
  }
  return result;
};

// --- mirror of huhs_push_send + huhs_push_continue -------------------------
const runBroadcast = (tokens, data, clock, attempt, slice = deliverSlice) => {
  const log = { attempted: [], runs: 0, pruned: [], jobs: 0 };
  const prune = (keys) => {
    for (const key of new Set(keys)) {
      if (key in tokens) {
        delete tokens[key];
        log.pruned.push(key);
      }
    }
  };
  const tracked = (key, token) => {
    log.attempted.push(key);
    return attempt(key, token);
  };

  const first = slice(recipients(tokens, data), clock, tracked);
  log.runs += 1;
  if (first.remaining > 0) {
    let job = { offset: first.processed, dead: first.dead, runs: 1 };
    log.jobs += 1;
    for (;;) {
      if (job.runs > MAX_RUNS) return { log, stoppedEarly: true };
      const list = recipients(tokens, data);
      const keys = Object.keys(list);
      const sliceList = {};
      for (const key of keys.slice(job.offset)) sliceList[key] = list[key];

      const pass = slice(sliceList, clock, tracked);
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
  prune(first.dead);
  return { log, stoppedEarly: false };
};

/**
 * Mirror of huhs_push_publish_news: one notification per article, a marker on
 * success, a bounded retry when nothing was delivered, and no retry at all when
 * there was nobody to notify.
 */
const newsNotification = (sentPerAttempt, recipientCount) => {
  const scheduled = [];
  for (let attempt = 1; attempt <= NEWS_MAX_ATTEMPTS; attempt += 1) {
    const sent = sentPerAttempt[attempt - 1] ?? 0;
    if (sent > 0) return { attemptsUsed: attempt, marked: true, scheduled, reason: 'ok' };
    if (recipientCount <= 0) return { attemptsUsed: attempt, marked: false, scheduled, reason: 'no-recipients' };
    if (attempt >= NEWS_MAX_ATTEMPTS) return { attemptsUsed: attempt, marked: false, scheduled, reason: 'gave-up' };
    scheduled.push(attempt);
  }
  return { attemptsUsed: NEWS_MAX_ATTEMPTS, marked: false, scheduled, reason: 'gave-up' };
};

const check = (name, condition, detail) => {
  console.log(`${condition ? 'OK   ' : 'HIBA '} ${name}${condition ? '' : ` — ${detail}`}`);
  return condition ? 0 : 1;
};

let failures = 0;

// 1. Everyone eligible gets exactly one send, nobody twice, dead tokens pruned.
{
  const tokens = makeTokens(895);
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
  console.log(`     (párhuzamos körök: ${log.runs}, párhuzamosság: ${CONCURRENCY}, 1 kör alatt ~${Math.floor(BUDGET / clock.latency) * CONCURRENCY} eszköz)`);
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
  failures += check('csak a bekapcsolt eszközök kaptak értesítést', seen.every((k) => Number(k.slice(3)) % 2 === 0), seen.join(','));
}

// 4. The serial fallback still does one device per pass and finishes.
{
  const tokens = makeTokens(40);
  const clock = { now: 0, latency: 20 }; // each send blows the whole budget
  const seen = [];
  const { log, stoppedEarly } = runBroadcast(tokens, { type: 'news' }, clock, (key) => {
    seen.push(key);
    return 'sent';
  }, deliverSliceSerial);
  failures += check('a tartalék (soros) út 1 eszköz / kör esetén is mindenkinek elküldi', seen.length === 40 && new Set(seen).size === 40, `sent=${seen.length}`);
  failures += check('a soros lánc így is megáll (nincs végtelen ciklus)', stoppedEarly === false && log.runs === 40, `runs=${log.runs}`);
}

// 5. A failed send is still progress, so the chain must run to the end and
//    must not delete anything.
{
  const tokens = makeTokens(500);
  const clock = { now: 0, latency: 0.2 };
  const { log, stoppedEarly } = runBroadcast(tokens, { type: 'news' }, clock, () => 'failed');
  failures += check('tartós FCM-hiba esetén is végigfut a lánc', stoppedEarly === false, `runs=${log.runs}`);
  failures += check('hibánál nem törlünk élő tokent', Object.keys(tokens).length === 500, `maradek=${Object.keys(tokens).length}`);
}

// 6. The run cap is the real safety rail: a pathologically slow delivery must
//    give up instead of looping forever.
{
  const tokens = makeTokens(5000);
  const clock = { now: 0, latency: 20 }; // one batch per run
  const { log, stoppedEarly } = runBroadcast(tokens, { type: 'news' }, clock, () => 'sent');
  failures += check('kórosan lassú kézbesítésnél a plafon megállítja a láncot', stoppedEarly === true && log.runs > MAX_RUNS, `runs=${log.runs}`);
}

// 7. The parallel path is only abandoned when it could not reach FCM at all,
//    and the fallback then actually delivers.
{
  const tokens = makeTokens(60);
  const clock = { now: 0, latency: 0.2 };
  const seen = [];
  const { log } = runBroadcast(tokens, { type: 'news' }, clock, (key) => {
    seen.push(key);
    return 'transport';
  });
  failures += check('hálózati hiba esetén a tartalék út is lefut, de nem töröl tokent', seen.length === 120 && log.pruned.length === 0, `probalkozas=${seen.length} pruned=${log.pruned.length}`);

  const tokens2 = makeTokens(60);
  const clock2 = { now: 0, latency: 0.2 };
  let call = 0;
  // The parallel attempt (60 calls) cannot reach FCM; the serial retry can.
  const { log: log2 } = runBroadcast(tokens2, { type: 'news' }, clock2, () => {
    call += 1;
    return call <= 60 ? 'transport' : 'sent';
  });
  failures += check('a tartalék út átveszi a küldést és mindenki megkapja', call === 120 && log2.pruned.length === 0, `hivas=${call}`);
}

// 8. The batching must not change the outcome: with concurrency 1 the parallel
//    path has to behave exactly like the serial one.
{
  const run = (slice) => {
    const tokens = makeTokens(200);
    const clock = { now: 0, latency: 0.1 };
    const seen = [];
    runBroadcast(tokens, { type: 'news' }, clock, (key) => {
      seen.push(key);
      return 'sent';
    }, slice);
    return seen;
  };
  const serial = run(deliverSliceSerial);
  const parallelOne = run((list, clock, attempt) => deliverSliceParallel(list, clock, attempt, 1));
  failures += check(
    '1-es párhuzamosságnál ugyanaz a sorrend, mint a soros úton',
    serial.join(',') === parallelOne.join(','),
    `serial=${serial.length} parallel=${parallelOne.length}`
  );
}

// 9. A news notification is never silently lost and never sent twice.
{
  const delivered = newsNotification([7, 0, 0], 900);
  failures += check('sikeres küldés után nincs újrapróba', delivered.attemptsUsed === 1 && delivered.marked === true && delivered.scheduled.length === 0, JSON.stringify(delivered));

  const late = newsNotification([0, 0, 9], 900);
  failures += check('két sikertelen kísérlet után a harmadik még kimegy', late.attemptsUsed === 3 && late.marked === true && late.scheduled.length === 2, JSON.stringify(late));

  const lost = newsNotification([0, 0, 0], 900);
  failures += check('három sikertelen kísérlet után jelzés nélkül feladja (nincs néma elveszés)', lost.attemptsUsed === 3 && lost.marked === false && lost.reason === 'gave-up', JSON.stringify(lost));

  const nobody = newsNotification([0, 0, 0], 0);
  failures += check('ha nincs kit értesíteni, nincs felesleges újrapróba', nobody.attemptsUsed === 1 && nobody.reason === 'no-recipients', JSON.stringify(nobody));
}

console.log(failures === 0 ? '\nMinden ellenőrzés sikeres.' : `\n${failures} ellenőrzés hibás.`);
process.exit(failures === 0 ? 0 : 1);

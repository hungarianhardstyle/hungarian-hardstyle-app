#!/usr/bin/env node
'use strict';
/*
 * tools/analyze-r8-config.mjs — R8 keep-rule blast-radius riport (CSAK OLVAS).
 *
 * Mire való: a Play Console „R8-optimalizálás" javaslata mögé nézni — megmutatja,
 * hogy a kód mekkora részét tartja vissza az optimalizálástól/obfuszkiálástól a
 * keep-szabályok sokasága, és hogy azok MELYIK konfigurációs fájlból jönnek
 * (a saját `proguard-rules.pro`-ból, vagy egy library beépített szabályából).
 *
 * A riportot a Gradle állítja elő (a projekt gyökeréből):
 *
 *   cd android
 *   .\gradlew.bat :app:analyzeReleaseR8Config `
 *     -P "HUHS_ADMOB_APP_ID=ca-app-pub-7714662594685378~1123886696" `
 *     -P "HUHS_ADMOB_BANNER_ID=ca-app-pub-7714662594685378/5219184964" `
 *     -P "HUHS_ADMOB_REWARDED_ID=ca-app-pub-7714662594685378/5286829694"
 *
 * Kimenet: build/app/reports/r8/r8-config-analyzer-release.html (+ .pb)
 * Ez az eszköz abból olvas; az appot NEM építi és NEM módosít semmit.
 *
 * Miért nem a skill Python szkriptjei futnak: ezen a gépen a `python.exe` egy
 * hibás architektúrájú stub, ezért a protobuft a repóban már meglévő
 * `functions/node_modules/protobufjs`-szal dekódoljuk.
 *
 * Használat:
 *   node tools/analyze-r8-config.mjs            # olvasható összegzés
 *   node tools/analyze-r8-config.mjs --json     # nyers JSON
 *   node tools/analyze-r8-config.mjs --top 25   # hány sort írjon ki
 */

import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const REPORT_DIR = path.join(ROOT, 'build', 'app', 'reports', 'r8');
const HTML = path.join(REPORT_DIR, 'r8-config-analyzer-release.html');
const PB = path.join(REPORT_DIR, 'r8-config-analyzer-release.pb');
const PROTO_OPEN = '<script id="keepradius-proto" type="text/plain">';
const DATA_RE = /<script id="keepradius-data" type="application\/octet-stream">([^<]+)<\/script>/;
const CONSTRAINT = ['DONT_OBFUSCATE', 'DONT_OPTIMIZE', 'DONT_SHRINK'];
const PACKAGE_WIDE_TAG = 0;

const args = process.argv.slice(2);
const asJson = args.includes('--json');
const topN = (() => {
  const i = args.indexOf('--top');
  const n = i >= 0 ? Number(args[i + 1]) : 12;
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 12;
})();

function fail(message) {
  console.error(message);
  process.exit(1);
}

function loadProtobuf() {
  for (const candidate of [
    path.join(ROOT, 'functions', 'node_modules', 'protobufjs'),
    path.join(ROOT, 'node_modules', 'protobufjs'),
  ]) {
    if (fs.existsSync(candidate)) return require(candidate);
  }
  fail('Nem találom a protobufjs-t (functions/node_modules/protobufjs).');
}

function readReport() {
  if (!fs.existsSync(HTML) && !fs.existsSync(PB)) {
    fail(
      'Nincs R8-riport. Futtasd előbb (az android mappából):\n' +
        '  .\\gradlew.bat :app:analyzeReleaseR8Config -P "HUHS_ADMOB_APP_ID=…" ' +
        '-P "HUHS_ADMOB_BANNER_ID=…" -P "HUHS_ADMOB_REWARDED_ID=…"',
    );
  }
  const protobuf = loadProtobuf();
  const html = fs.existsSync(HTML) ? fs.readFileSync(HTML, 'utf8') : '';
  const open = html.indexOf(PROTO_OPEN);
  if (open < 0) fail('A riport HTML-jében nincs benne a keep-radius protoséma.');
  const protoText = html.slice(open + PROTO_OPEN.length, html.indexOf('</script>', open));
  const root = protobuf.parse(protoText, { keepCase: true }).root;
  const container = root.lookupType('com.android.tools.r8.keepradius.proto.KeepRadiusContainer');
  const inline = DATA_RE.exec(html);
  const bytes = inline ? Buffer.from(inline[1].trim(), 'base64') : fs.readFileSync(PB);
  return container.toObject(container.decode(bytes), {
    longs: Number,
    enums: Number,
    defaults: true,
    arrays: true,
    keepCase: true,
  });
}

const shorten = (p) => String(p || '').split(/[\\/]/).slice(-3).join('/');

function analyze(data) {
  const constraintsById = new Map(
    data.keep_constraints_table.map((c) => [c.id, new Set((c.constraints || []).map((n) => CONSTRAINT[n] || String(n)))]),
  );
  const rulesById = new Map(
    data.keep_rule_keep_radius_table.map((r) => [r.id, constraintsById.get(r.constraints_id) || new Set()]),
  );
  const globalSources = data.global_keep_rule_keep_radius_table.map((g) => (g.source || '').toLowerCase());

  let totItems = 0;
  let blockedOptimize = 0;
  let blockedObfuscate = 0;
  let blockedShrink = 0;
  const keptByOrigin = new Map();
  const keptKinds = { class: 0, field: 0, method: 0 };

  for (const [table, kind] of [
    [data.kept_class_info_table, 'class'],
    [data.kept_field_info_table, 'field'],
    [data.kept_method_info_table, 'method'],
  ]) {
    for (const item of table) {
      totItems += 1;
      keptKinds[kind] += 1;
      const bucket = keptByOrigin.get(item.file_origin_id) || { class: 0, field: 0, method: 0 };
      bucket[kind] += 1;
      keptByOrigin.set(item.file_origin_id, bucket);
      let opt = false;
      let obf = false;
      let shr = false;
      for (const id of item.kept_by || []) {
        const cons = rulesById.get(id);
        if (!cons) continue;
        if (cons.has('DONT_OPTIMIZE')) opt = true;
        if (cons.has('DONT_OBFUSCATE')) obf = true;
        if (cons.has('DONT_SHRINK')) shr = true;
      }
      if (opt) blockedOptimize += 1;
      if (obf) blockedObfuscate += 1;
      if (shr) blockedShrink += 1;
    }
  }

  const bi = data.build_info || {};
  const live = (bi.live_class_count || 0) + (bi.live_field_count || 0) + (bi.live_method_count || 0);
  const denominator = live > 0 ? live : totItems;
  const score = (count, flag) => (globalSources.some((s) => s.includes(flag)) ? 0 : Math.max(0, 100 - (count / denominator) * 100));

  const originLabel = (id) => {
    const file = data.file_origin_table.find((f) => f.id === id);
    if (file) return shorten(file.filename) || `origin#${id}`;
    const jar = data.class_file_in_jar_origin_table.find((j) => j.id === id);
    if (jar) {
      const parent = data.file_origin_table.find((f) => f.id === jar.file_origin_id);
      return shorten((parent && parent.filename) || jar.entry) || `jar#${id}`;
    }
    return `origin#${id}`;
  };

  const origins = [...keptByOrigin.entries()]
    .map(([id, e]) => ({ origin: originLabel(id), ...e, items: e.class + e.field + e.method }))
    .filter((r) => r.items > 0)
    .sort((a, b) => b.items - a.items)
    .map((r) => ({ ...r, pct: (r.items / totItems) * 100 }));

  const ruleRow = (r) => {
    const radius = r.keep_radius || {};
    const classes = (radius.class_keep_radius || []).length;
    const fields = (radius.field_keep_radius || []).length;
    const methods = (radius.method_keep_radius || []).length;
    const origin = r.origin || {};
    const file = data.file_origin_table.find((f) => f.id === origin.file_origin_id);
    return {
      id: r.id,
      rule: (r.source || '').trim(),
      from: file ? shorten(file.filename) : '',
      constraints: [...(rulesById.get(r.id) || [])].join('+'),
      packageWide: (r.tags || []).includes(PACKAGE_WIDE_TAG),
      classes,
      fields,
      methods,
      impact: classes + fields + methods,
      impactPct: ((classes + fields + methods) / denominator) * 100,
      subsumedBy: (radius.subsumed_by || []).length,
    };
  };

  const rules = data.keep_rule_keep_radius_table.map(ruleRow).filter((r) => r.impact > 0);
  const bySource = new Map();
  for (const r of rules) {
    const e = bySource.get(r.from) || { from: r.from, rules: 0, impact: 0, packageWide: 0 };
    e.rules += 1;
    e.impact += r.impact;
    if (r.packageWide) e.packageWide += 1;
    bySource.set(r.from, e);
  }
  const sources = [...bySource.values()]
    .map((e) => ({ ...e, pct: (e.impact / denominator) * 100 }))
    .sort((a, b) => b.impact - a.impact);

  const projectRuleIds = new Set(
    data.keep_rule_keep_radius_table
      .filter((r) => {
        const origin = r.origin || {};
        const file = data.file_origin_table.find((f) => f.id === origin.file_origin_id);
        return file && /proguard-rules\.pro$/i.test(file.filename || '');
      })
      .map((r) => r.id),
  );
  const exclusive = new Map([...projectRuleIds].map((id) => [id, 0]));
  const projectTouched = { class: 0, field: 0, method: 0 };
  for (const [table, kind] of [
    [data.kept_class_info_table, 'class'],
    [data.kept_field_info_table, 'field'],
    [data.kept_method_info_table, 'method'],
  ]) {
    for (const item of table) {
      const keptBy = item.kept_by || [];
      if (!keptBy.some((id) => projectRuleIds.has(id))) continue;
      projectTouched[kind] += 1;
      if (keptBy.every((id) => projectRuleIds.has(id))) {
        for (const id of keptBy) exclusive.set(id, (exclusive.get(id) || 0) + 1);
      }
    }
  }
  const touchedTotal = projectTouched.class + projectTouched.field + projectTouched.method;

  return {
    buildInfo: { liveClasses: bi.live_class_count, liveFields: bi.live_field_count, liveMethods: bi.live_method_count, denominator },
    keptItems: { total: totItems, ...keptKinds },
    scores: {
      optimization: score(blockedOptimize, '-dontoptimize'),
      obfuscation: score(blockedObfuscate, '-dontobfuscate'),
      shrinking: score(blockedShrink, '-dontshrink'),
      blocked: { optimize: blockedOptimize, obfuscate: blockedObfuscate, shrink: blockedShrink },
    },
    globalDisableRules: globalSources,
    topOrigins: origins.slice(0, topN),
    topRules: rules.slice().sort((a, b) => b.impact - a.impact).slice(0, topN),
    subsumedRuleCount: rules.filter((r) => r.subsumedBy > 0).length,
    sources,
    projectRules: {
      ruleCount: projectRuleIds.size,
      touched: projectTouched,
      touchedTotal,
      touchedPct: (touchedTotal / denominator) * 100,
      exclusiveTotal: [...exclusive.values()].reduce((s, n) => s + n, 0),
      exclusivePct: ([...exclusive.values()].reduce((s, n) => s + n, 0) / denominator) * 100,
      exclusiveByRule: [...exclusive.entries()]
        .map(([id, n]) => {
          const r = data.keep_rule_keep_radius_table.find((x) => x.id === id) || {};
          return { rule: (r.source || '').trim().split('\n')[0], exclusiveItems: n, exclusivePct: (n / denominator) * 100 };
        })
        .filter((r) => r.exclusiveItems > 0)
        .sort((a, b) => b.exclusiveItems - a.exclusiveItems),
    },
    counts: { keepRules: data.keep_rule_keep_radius_table.length, globalKeepRules: globalSources.length, keptItems: totItems },
  };
}

const pct = (n) => `${n.toFixed(2)}%`;

// ---- önteszt: a pontszámítás és az „exkluzív" számítás a szintetikus adaton ----
function selfTest() {
  const synthetic = (blockedItems, globalRule) => ({
    keep_constraints_table: [
      { id: 1, constraints: [1] }, // DONT_OPTIMIZE
      { id: 2, constraints: [] },
    ],
    keep_rule_keep_radius_table: [
      { id: 10, source: '-keep class com.example.** { *; }', constraints_id: 1, origin: { file_origin_id: 1 }, keep_radius: { subsumed_by: [], class_keep_radius: [], field_keep_radius: [], method_keep_radius: [0, 1, 2, 3] }, tags: [0] },
      { id: 11, source: '-keepclassmembers class com.example.A { <init>(); }', constraints_id: 2, origin: { file_origin_id: 1 }, keep_radius: { subsumed_by: [], class_keep_radius: [], field_keep_radius: [], method_keep_radius: [] }, tags: [] },
    ],
    global_keep_rule_keep_radius_table: globalRule ? [{ id: 99, source: globalRule }] : [],
    file_origin_table: [{ id: 1, filename: '/repo/android/app/proguard-rules.pro', maven_coordinate: 0, provided_by_build_system: false }],
    class_file_in_jar_origin_table: [],
    kept_class_info_table: [],
    kept_field_info_table: [],
    kept_method_info_table: Array.from({ length: 4 }, (_, i) => ({
      id: i,
      method_reference_id: i,
      file_origin_id: 1,
      kept_by: i < blockedItems ? [10] : [11],
    })),
    build_info: { live_class_count: 0, live_field_count: 0, live_method_count: 4 },
  });

  const cases = [
    ['minden elem blokkolva → 0% optimalizálás', analyze(synthetic(4, null)).scores.optimization === 0],
    ['a fele blokkolva → 50% optimalizálás', analyze(synthetic(2, null)).scores.optimization === 50],
    ['semmi sincs blokkolva → 100% optimalizálás', analyze(synthetic(0, null)).scores.optimization === 100],
    ['globális -dontoptimize → 0%', analyze(synthetic(0, '-dontoptimize')).scores.optimization === 0],
    ['a projekt-szabály exkluzív hatása számol', analyze(synthetic(4, null)).projectRules.exclusiveTotal === 4],
    ['a package-wide címke felismerve', analyze(synthetic(4, null)).topRules.some((r) => r.packageWide)],
  ];
  let failed = 0;
  for (const [name, ok] of cases) {
    console.log(`  ${ok ? 'OK  ' : 'HIBA'} ${name}`);
    if (!ok) failed += 1;
  }
  console.log(failed === 0 ? `ÖNTESZT: ${cases.length}/${cases.length} OK` : `ÖNTESZT: ${failed} bukott`);
  process.exit(failed === 0 ? 0 : 1);
}

if (args.includes('--self-test')) {
  selfTest();
}

const result = analyze(readReport());

if (asJson) {
  console.log(JSON.stringify(result, null, 2));
} else {
  const s = result.scores;
  console.log('R8 keep-szabály riport (csak olvasás) — ' + shorten(HTML));
  console.log(`  élő elemek (nevező): ${result.buildInfo.denominator}  ` +
    `(osztály ${result.buildInfo.liveClasses}, mező ${result.buildInfo.liveFields}, metódus ${result.buildInfo.liveMethods})`);
  console.log(`  optimalizálás: ${pct(s.optimization)}   obfuszkiálás: ${pct(s.obfuscation)}   csökkentés: ${pct(s.shrinking)}`);
  console.log(`  blokkolt elemek: optimalizálás ${s.blocked.optimize}, obfuszkiálás ${s.blocked.obfuscate}, csökkentés ${s.blocked.shrink}`);
  if (result.globalDisableRules.length) {
    console.log(`  ⚠️ globális tiltó szabály: ${result.globalDisableRules.join(', ')}`);
  } else {
    console.log('  globális tiltó szabály (-dontoptimize/-dontobfuscate/-dontshrink): NINCS');
  }
  console.log(`\nHonnan jön a visszatartott kód (${result.counts.keepRules} keep-szabály, fájlonként):`);
  for (const row of result.sources.slice(0, topN)) {
    console.log(`  ${pct(row.pct).padStart(7)}  ${String(row.impact).padStart(7)} elem  ${row.rules} szabály` +
      `${row.packageWide ? ` (${row.packageWide} package-wide)` : ''}  ${row.from}`);
  }
  console.log('\nA legnagyobb hatású keep-szabályok:');
  for (const r of result.topRules) {
    console.log(`  ${pct(r.impactPct).padStart(7)}  osztály ${r.classes}, mező ${r.fields}, metódus ${r.methods}` +
      `${r.packageWide ? ' [package-wide]' : ''}  ← ${r.from}`);
    console.log(`           ${r.rule.replace(/\s+/g, ' ').slice(0, 110)}`);
  }
  console.log(`\nA MI szabályaink (android/app/proguard-rules.pro): ${result.projectRules.ruleCount} szabály, ` +
    `${result.projectRules.touchedTotal} elemet érint (${pct(result.projectRules.touchedPct)}), ` +
    `ebből KIZÁRÓLAG általunk tartott: ${result.projectRules.exclusiveTotal} (${pct(result.projectRules.exclusivePct)})`);
  for (const r of result.projectRules.exclusiveByRule) {
    console.log(`  ${pct(r.exclusivePct).padStart(7)}  ${r.rule.slice(0, 100)}`);
  }
  console.log(`\n  (subsumed szabályok: ${result.subsumedRuleCount})`);
}

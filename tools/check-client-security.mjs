// https://firebase.google.com/support/guides/compromised-emudhra-intermediate-ca
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

function atLeast(actual, minimum) {
  assert.match(actual, /^\d+\.\d+\.\d+$/);
  const a = actual.split('.').map(Number);
  const b = minimum.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if (a[i] !== b[i]) return a[i] > b[i];
  }
  return true;
}

const patchedFirestore = (v) => v === '6.10.2' || atLeast(v, '7.1.0');
const patchedApple = (v) => v === '12.19.3' || atLeast(v, '13.1.1');

function appleResolved(directory) {
  const versions = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) versions.push(...appleResolved(file));
    else if (entry.name === 'Package.resolved') {
      const resolved = JSON.parse(fs.readFileSync(file, 'utf8'));
      for (const pin of resolved.pins ?? resolved.object?.pins ?? []) {
        if ((pin.identity ?? pin.package)?.toLowerCase() === 'firebase-ios-sdk') {
          versions.push(pin.state.version);
        }
      }
    }
  }
  return versions;
}

if (process.argv.includes('--self-test')) {
  assert.equal(atLeast('3.13.2', '3.13.7'), false);
  assert.equal(atLeast('3.13.7', '3.13.7'), true);
  assert.equal(atLeast('3.13.10', '3.13.7'), true);
  assert.equal(atLeast('6.10.0', '6.10.2'), false);
  assert.equal(atLeast('6.10.1', '6.10.2'), false);
  assert.equal(atLeast('12.19.0', '12.19.3'), false);
  assert.equal(patchedFirestore('7.0.0'), false);
  assert.equal(patchedFirestore('6.10.2'), true);
  assert.equal(patchedFirestore('7.1.0'), true);
  assert.equal(patchedApple('13.1.0'), false);
  assert.equal(patchedApple('12.19.3'), true);
  assert.equal(patchedApple('13.1.1'), true);
  assert.throws(() => atLeast('3.13.7-beta', '3.13.7'));
  console.log('Security gate self-test passed');
} else {
  const output = process.platform === 'win32'
    ? execFileSync('cmd.exe', ['/d', '/s', '/c', 'flutter --version --machine'], { encoding: 'utf8' })
    : execFileSync('flutter', ['--version', '--machine'], { encoding: 'utf8' });
  const sdk = JSON.parse(output);
  const check = (name, actual, minimum) => {
    assert.ok(atLeast(actual, minimum), `${name}: ${actual}; required >= ${minimum}`);
    console.log(`${name}: ${actual} (>= ${minimum})`);
  };
  check('Flutter', sdk.frameworkVersion, '3.47.8');
  check('Dart', sdk.dartSdkVersion.split(' ')[0], '3.13.7');

  const lock = fs.readFileSync('pubspec.lock', 'utf8');
  for (const [name, minimum] of Object.entries({
    firebase_core: '4.15.2', cloud_firestore: '6.10.2',
    firebase_analytics: '12.6.1', firebase_app_check: '0.4.9',
  })) {
    const block = lock.match(new RegExp(`^  ${name}:\\r?\\n([\\s\\S]*?)(?=^  \\w|^sdks:)`, 'm'));
    const version = block?.[1].match(/version: "([^"]+)"/)?.[1];
    assert.ok(version, `Missing resolved package: ${name}`);
    check(name, version, minimum);
    if (name === 'cloud_firestore') assert.ok(patchedFirestore(version));
  }

  const configUrl = new URL('../.dart_tool/package_config.json', import.meta.url);
  const packages = JSON.parse(fs.readFileSync(configUrl, 'utf8')).packages;
  const core = packages.find((p) => p.name === 'firebase_core');
  assert.ok(core, 'firebase_core is not resolved');
  const coreUrl = new URL(core.rootUri.endsWith('/') ? core.rootUri : `${core.rootUri}/`, configUrl);
  const swift = fs.readFileSync(new URL('ios/firebase_core/Package.swift', coreUrl), 'utf8');
  const nativeVersion = swift.match(/firebaseSdkVersion: Version = "([^"]+)"/)?.[1];
  assert.ok(nativeVersion, `Missing Apple SDK pin in ${fileURLToPath(coreUrl)}`);
  check('Firebase Apple SDK (resolved plugin SPM pin)', nativeVersion, '12.19.3');
  assert.ok(patchedApple(nativeVersion), 'Unpatched Firebase Apple SDK');
  if (process.argv.includes('--apple-resolved')) {
    const versions = appleResolved('ios');
    assert.ok(versions.length > 0, 'Xcode Firebase Package.resolved not found');
    for (const version of versions) {
      assert.ok(patchedApple(version), `Unpatched Xcode Firebase SDK: ${version}`);
      console.log(`Xcode resolved Firebase SDK: ${version}`);
    }
  }
  console.log('Client SDK security gate passed');
}

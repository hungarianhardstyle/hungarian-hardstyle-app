const test = require('node:test');
const assert = require('node:assert/strict');
const { cloudinarySignature, selectOwnedCloudinaryAssets, destroyCloudinaryAsset, listOwnedCloudinaryAssets } = require('./cloudinary');

test('signed deletion succeeds for an owned public_id', async () => {
  let request;
  const result = await destroyCloudinaryAsset({
    cloudName: 'fjxo93em', apiKey: 'key', apiSecret: 'secret', publicId: 'huhs/users/u1/profile', now: () => 1700000000000,
    fetchImpl: async (url, options) => { request = { url, options }; return { ok: true, json: async () => ({ result: 'ok' }) }; },
  });
  assert.equal(result.status, 'deleted');
  assert.match(request.url, /image\/destroy$/);
  assert.match(String(request.options.body), /public_id=huhs%2Fusers%2Fu1%2Fprofile/);
  assert.equal(cloudinarySignature({ a: '1', b: '2' }, 'secret').length, 40);
});

test('already absent Cloudinary object is successful and retryable', async () => {
  let calls = 0;
  const result = await destroyCloudinaryAsset({
    cloudName: 'c', apiKey: 'k', apiSecret: 's', publicId: 'missing',
    fetchImpl: async () => { calls += 1; return { ok: true, json: async () => ({ result: 'not found' }) }; },
  });
  assert.equal(result.status, 'deleted');
  assert.equal(calls, 1);
});

test('transient Cloudinary failure is not reported as deleted', async () => {
  await assert.rejects(() => destroyCloudinaryAsset({
    cloudName: 'c', apiKey: 'k', apiSecret: 's', publicId: 'retry',
    fetchImpl: async () => ({ ok: false, json: async () => ({ result: 'error' }) }),
  }), /cloudinary-delete-temporary-failure/);
});

test('only the matching owner is selected', () => {
  const result = selectOwnedCloudinaryAssets('u1', [
    { ownerUid: 'u1', publicId: 'one', secureUrl: 'https://res.cloudinary.com/fjxo93em/image/upload/one' },
    { ownerUid: 'u2', publicId: 'two', secureUrl: 'https://res.cloudinary.com/fjxo93em/image/upload/two' },
  ]);
  assert.deepEqual(result.assets.map((asset) => asset.publicId), ['one']);
});

test('missing public_id requires manual cleanup and never completes automatically', () => {
  const result = selectOwnedCloudinaryAssets('u1', [{
    ownerUid: 'u1', publicId: '', secureUrl: 'https://res.cloudinary.com/fjxo93em/image/upload/legacy',
  }]);
  assert.equal(result.assets.length, 0);
  assert.equal(result.manualCleanupRequired, true);
});

test('missing secrets fail before any request', async () => {
  await assert.rejects(() => destroyCloudinaryAsset({
    cloudName: 'c', publicId: 'asset', fetchImpl: async () => assert.fail('request must not run'),
  }), /cloudinary-secret-not-configured/);
});

test('resource listing is restricted to the UID-owned Cloudinary prefix', async () => {
  const assets = await listOwnedCloudinaryAssets({
    cloudName: 'c', apiKey: 'k', apiSecret: 's', uid: 'u1',
    fetchImpl: async (url, options) => {
      assert.match(url, /prefix=huhs_users%2Fu1%2F/);
      assert.match(options.headers.Authorization, /^Basic /);
      return { ok: true, json: async () => ({ resources: [
        { public_id: 'huhs_users/u1/a' }, { public_id: 'huhs_users/u2/b' },
      ] }) };
    },
  });
  assert.deepEqual(assets.map((asset) => asset.publicId), ['huhs_users/u1/a']);
});

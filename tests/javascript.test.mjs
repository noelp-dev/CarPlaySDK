import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createCarPlay, CarPlayError } from '../resources/js/carplay.mjs';

test('uses NativePHP endpoint and unwraps controller envelope', async () => {
  const requests = [];
  const car = createCarPlay({ fetch: async (url, init) => {
    requests.push([url, JSON.parse(init.body)]);
    return { ok: true, json: async () => ({ status: 'success', data: { accepted: true, operationId: 'op' } }) };
  } });
  const result = await car.navigate(52.37, 4.89, 'Garage');
  assert.deepEqual(result, { accepted: true, operationId: 'op' });
  assert.deepEqual(requests[0], ['/_native/api/call', { method: 'CarPlay.Navigate', params: { latitude: 52.37, longitude: 4.89, name: 'Garage' } }]);
  await car.events(); await car.acknowledge(['event']); await car.status();
  assert.equal(requests[1][1].params.limit, 100);
  assert.deepEqual(requests[2][1].params.ids, ['event']);
  assert.deepEqual(requests[3][1].params, {});
});
test('preserves native error code and message', async () => {
  const car = createCarPlay({ fetch: async () => ({ ok: false, status: 400, json: async () => ({ status: 'error', code: 'UNSUPPORTED', message: 'No modal' }) }) });
  await assert.rejects(car.dismiss(), e => e instanceof CarPlayError && e.code === 'UNSUPPORTED' && e.message === 'No modal');
});
test('rejects invalid JSON and invalid envelope data', async () => {
  for (const body of [null, 'not an object', []]) {
    const car = createCarPlay({ fetch: async () => ({ ok: true, json: async () => ({ status: 'success', data: body }) }) });
    await assert.rejects(car.status(), e => e.code === 'INVALID_RESPONSE');
  }
  const car = createCarPlay({ fetch: async () => ({ ok: true, json: async () => { throw new Error('bad json'); } }) });
  await assert.rejects(car.status(), e => e.code === 'INVALID_RESPONSE');
});

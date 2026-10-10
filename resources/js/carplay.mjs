export class CarPlayError extends Error {
  constructor(code, message) { super(message); this.name = 'CarPlayError'; this.code = code; }
}

/** The native implementations validate the shared wire contract for JS callers too. */
export function createCarPlay({ fetch: fetcher = globalThis.fetch, endpoint = '/_native/api/call' } = {}) {
  async function call(command, params = {}) {
    const response = await fetcher(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify({ method: `CarPlay.${command}`, params }),
    });
    let result;
    try { result = await response.json(); } catch { throw new CarPlayError('INVALID_RESPONSE', 'Native bridge returned invalid JSON.'); }
    if (result?.status === 'error' || !response.ok) {
      throw new CarPlayError(result?.code ?? 'HTTP_ERROR', result?.message ?? `Native bridge returned HTTP ${response.status}.`);
    }
    if (result?.status === 'success') result = result.data;
    if (result === null || typeof result !== 'object' || Array.isArray(result)) {
      throw new CarPlayError('INVALID_RESPONSE', 'Native bridge must return an object.');
    }
    return result;
  }
  return Object.freeze({
    capabilities: () => call('Capabilities'), status: () => call('Status'),
    setRoot: template => call('SetRoot', { template }), push: template => call('Push', { template }),
    replace: template => call('Replace', { template }), pop: () => call('Pop'), popToRoot: () => call('PopToRoot'),
    present: template => call('Present', { template }), dismiss: () => call('Dismiss'), clear: () => call('Clear'),
    navigate: (latitude, longitude, name = '') => call('Navigate', { latitude, longitude, name }),
    events: (limit = 100) => call('Events', { limit }), acknowledge: ids => call('Acknowledge', { ids }),
    bindEvents: () => call('BindEvents'),
  });
}
export const CarPlay = createCarPlay();

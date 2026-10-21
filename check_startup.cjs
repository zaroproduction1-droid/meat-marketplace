const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const root = path.join(__dirname, 'web');
const startup = fs.readFileSync(path.join(root, 'cutlink_startup.js'), 'utf8');
const bootstrap = fs.readFileSync(path.join(root, 'flutter_bootstrap.js'), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');
let checks = 0;
function harness(online = true) {
  const elements = Object.fromEntries(['cutlink-startup', 'startup-status', 'startup-recovery', 'startup-retry'].map(id => [id, {
    hidden: id === 'startup-recovery', textContent: '', removed: false,
    remove() { this.removed = true; },
    addEventListener(name, callback) { this[name] = callback; },
  }]));
  const events = {};
  let timer;
  let reloads = 0;
  const window = {
    addEventListener(name, callback) { events[name] = callback; },
    removeEventListener(name) { delete events[name]; },
  };
  const context = vm.createContext({ window, navigator: { onLine: online },
    document: { getElementById: id => elements[id] },
    location: { reload() { reloads++; } },
    setTimeout(callback) { timer = callback; return 1; }, clearTimeout() { timer = null; },
  });
  vm.runInContext(startup, context);
  return { context, window, elements, events, timeout() { timer?.(); }, get reloads() { return reloads; } };
}
async function boot(h, loader) {
  h.context._flutter = { loader: { load: loader } };
  vm.runInContext(bootstrap, h.context);
  await new Promise(resolve => setImmediate(resolve));
}
(async () => {
  let h = harness();
  assert.match(h.elements['startup-status'].textContent, /Opening/); checks++;
  h.timeout();
  assert.equal(h.elements['startup-recovery'].hidden, false); checks++;
  h.window.cutlinkStartup.ready();
  assert.equal(h.elements['cutlink-startup'].removed, true); checks++;
  h = harness(false);
  assert.match(h.elements['startup-status'].textContent, /offline/); checks++;
  h.context.navigator.onLine = true;
  h.events.online();
  assert.match(h.elements['startup-status'].textContent, /Opening/); checks++;
  h.elements['startup-retry'].click();
  assert.equal(h.reloads, 1); checks++;
  h = harness();
  h.events.error({ target: { id: 'cutlink-bootstrap' } });
  assert.equal(h.elements['startup-recovery'].hidden, false); checks++;
  h = harness();
  await boot(h, ({ onEntrypointLoaded }) => onEntrypointLoaded({ initializeEngine: async () => ({ runApp: async () => {} }) }));
  assert.equal(h.elements['cutlink-startup'].removed, true); checks++;
  h = harness();
  await boot(h, () => Promise.reject(new Error('download failed')));
  assert.equal(h.elements['startup-recovery'].hidden, false); checks++;
  h = harness();
  await boot(h, () => { throw new Error('loader failed'); });
  assert.equal(h.elements['startup-recovery'].hidden, false); checks++;
  h = harness();
  await boot(h, ({ onEntrypointLoaded }) => onEntrypointLoaded({ initializeEngine: async () => { throw new Error('engine failed'); } }));
  assert.equal(h.elements['startup-recovery'].hidden, false); checks++;
  h = harness();
  await boot(h, ({ onEntrypointLoaded }) => onEntrypointLoaded({ initializeEngine: async () => ({ runApp: async () => { throw new Error('app failed'); } }) }));
  assert.equal(h.elements['startup-recovery'].hidden, false); checks++;
  console.log(`PASS: ${checks} mocked startup checks (not a Flutter/browser build).`);
})().catch(error => { console.error(error); process.exitCode = 1; });

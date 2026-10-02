import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../web/flutter_bootstrap.js', import.meta.url), 'utf8')
  .replace('{{flutter_js}}', '').replace('{{flutter_build_config}}', '');

test('installed PWA starts without registering or waiting for network', async () => {
  const active = {active: {}};
  let registrations = 0;
  let started = false;
  let watched;
  await vm.runInNewContext(source, {
    URL, console,
    document: {baseURI: 'https://example.org/app/'},
    navigator: {serviceWorker: {
      controller: {},
      getRegistration: async () => active,
      register: () => { registrations++; throw Error('Offline network must not block startup'); },
    }},
    window: {kassenmeisterUpdates: {watch: (registration) => { watched = registration; }}},
    _flutter: {loader: {load: async ({config}) => {
      assert.equal(config.canvasKitBaseUrl, 'https://example.org/app/canvaskit/');
      started = true;
    }}},
  });
  assert.equal(started, true);
  assert.equal(registrations, 0);
  assert.equal(watched, active);
});

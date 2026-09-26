{{flutter_js}}
{{flutter_build_config}}

(async () => {
  // Use the bundled engine on Safari and Chromium, never the Google CDN.
  const config = {canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).href};
  if ('serviceWorker' in navigator) {
    try {
      const registration = await navigator.serviceWorker.register(
        new URL('flutter_service_worker.js', document.baseURI),
        {updateViaCache: 'none'},
      );
      window.kassenmeisterUpdates?.watch(registration);
      if (!registration.active) {
        window.pluStartup?.status('Offline-Dateien werden vorbereitet …');
        // First launch: allow the complete app shell to finish caching. A slow
        // or failed cache must not prevent using the app while online.
        await new Promise((resolve, reject) => {
          const worker = registration.installing || registration.waiting;
          if (!worker) return reject(new Error('No service worker available'));
          const timeout = setTimeout(() => {
            cleanup();
            reject(new Error('Offline preparation timed out'));
          }, 20000);
          const cleanup = () => {
            clearTimeout(timeout);
            worker.removeEventListener('statechange', check);
          };
          const check = () => {
            if (worker.state === 'activated') {
              cleanup();
              resolve();
            } else if (worker.state === 'redundant') {
              cleanup();
              reject(new Error('Offline preparation failed'));
            }
          };
          worker.addEventListener('statechange', check);
          check();
        });
      }
    } catch (error) {
      console.warn('Offline cache unavailable:', error);
    }
  }
  window.pluStartup?.status('App wird gestartet …');
  await _flutter.loader.load({
    config,
    onEntrypointLoaded: async (engineInitializer) => {
      try {
        const appRunner = await engineInitializer.initializeEngine(config);
        await appRunner.runApp();
      } catch (error) {
        window.pluStartup?.fail(error);
      }
    },
  });
})().catch((error) => window.pluStartup?.fail(error));

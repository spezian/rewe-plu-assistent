(() => {
  if (!('serviceWorker' in navigator)) return;

  const banner = document.getElementById('app-update');
  const dialog = document.getElementById('update-confirm');
  const restart = document.getElementById('update-restart');
  const error = document.getElementById('update-error');
  let registration;
  let appStarted = false;
  let dismissed = false;
  let requested = false;
  let reloading = false;
  let changedController = false;
  let knownController = navigator.serviceWorker.controller;
  let lastCheck = 0;

  const showAvailable = () => {
    const ready = registration?.waiting || changedController;
    banner.hidden = !(appStarted && ready && !dismissed);
  };
  window.addEventListener('flutter-first-frame', () => {
    appStarted = true;
    showAvailable();
  }, {once: true});

  const checkForUpdates = () => {
    if (!registration || !navigator.onLine || document.visibilityState !== 'visible') return;
    if (Date.now() - lastCheck < 60000) return;
    lastCheck = Date.now();
    registration.update().catch(() => {}); // Offline/failed checks keep the current app.
  };
  window.addEventListener('online', checkForUpdates);
  document.addEventListener('visibilitychange', checkForUpdates);

  window.kassenmeisterUpdates = {
    watch(value) {
      registration = value;
      const watchInstalling = () => {
        const worker = registration.installing;
        if (!worker) return;
        worker.addEventListener('statechange', () => {
          // "installed" only occurs after the entire offline download succeeds.
          if (worker.state === 'installed' && navigator.serviceWorker.controller) {
            showAvailable();
          }
        });
      };
      registration.addEventListener('updatefound', watchInstalling);
      watchInstalling();
      showAvailable();
      checkForUpdates();
    },
  };

  const reload = () => {
    if (reloading) return;
    reloading = true;
    location.reload();
  };
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    const controller = navigator.serviceWorker.controller;
    // Claiming the page during the very first installation is not an update.
    if (knownController && controller !== knownController) {
      changedController = true;
      if (requested) reload();
      else showAvailable(); // Never reload another tab without its user's consent.
    }
    knownController = controller;
  });

  document.getElementById('update-later').addEventListener('click', () => {
    dismissed = true;
    banner.hidden = true;
  });
  document.getElementById('update-now').addEventListener('click', () => {
    error.hidden = true;
    dialog.showModal();
  });
  document.getElementById('update-cancel').addEventListener('click', () => {
    if (!requested) dialog.close();
  });
  dialog.addEventListener('cancel', (event) => {
    if (requested) event.preventDefault();
  });

  restart.addEventListener('click', async () => {
    if (requested) return;
    requested = true;
    restart.disabled = true;
    error.hidden = true;
    const worker = registration?.waiting;
    if (!worker && changedController) return reload();
    try {
      if (!worker) throw new Error('Das Update ist noch nicht bereit. Bitte später erneut versuchen.');
      await new Promise((resolve, reject) => {
        const channel = new MessageChannel();
        const timer = setTimeout(() => {
          channel.port1.close();
          reject(new Error('Das Update konnte nicht gestartet werden. Bitte erneut versuchen.'));
        }, 10000);
        channel.port1.onmessage = ({data}) => {
          clearTimeout(timer);
          channel.port1.close();
          if (data?.ok) resolve();
          else reject(new Error(data?.reason === 'OTHER_WINDOWS'
            ? 'Bitte schließe zuerst die anderen Kassenmeister-Fenster oder -Tabs und versuche es erneut.'
            : 'Das Update konnte nicht gestartet werden. Bitte erneut versuchen.'));
        };
        worker.postMessage({type: 'ACTIVATE_UPDATE'}, [channel.port2]);
      });
      // The controllerchange event performs the reload once activation finishes.
    } catch (failure) {
      requested = false;
      restart.disabled = false;
      error.textContent = failure.message;
      error.hidden = false;
    }
  });
})();

// Startup UI only. No user data, storage, tracking or offline write queue.
(() => {
  'use strict';
  const shell = document.getElementById('cutlink-startup');
  const status = document.getElementById('startup-status');
  const recovery = document.getElementById('startup-recovery');
  let finished = false;
  let failed = false;
  function connection() {
    if (finished) return;
    if (navigator.onLine === false) {
      status.textContent = 'You appear to be offline. Reconnect, then try again.';
      recovery.hidden = false;
    } else if (failed) {
      status.textContent = 'CutLink could not finish opening. Please try again.';
    } else {
      status.textContent = 'Opening your workspace…';
    }
  }
  function fail() {
    if (finished) return;
    failed = true;
    recovery.hidden = false;
    connection();
  }
  const timeout = setTimeout(fail, 45000);
  window.addEventListener('online', connection);
  window.addEventListener('offline', connection);
  window.addEventListener('error', event => {
    if (event.target && event.target.id === 'cutlink-bootstrap') fail();
  }, true);
  document.getElementById('startup-retry').addEventListener('click', () => location.reload());
  window.cutlinkStartup = Object.freeze({
    fail,
    ready() {
      if (finished) return;
      finished = true;
      clearTimeout(timeout);
      window.removeEventListener('online', connection);
      window.removeEventListener('offline', connection);
      shell.remove();
    },
  });
  connection();
})();

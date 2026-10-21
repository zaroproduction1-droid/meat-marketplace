{{flutter_js}}
{{flutter_build_config}}

// Flutter replaces the tokens above at build time. Do not remove them.
try {
  const loading = _flutter.loader.load({
    onEntrypointLoaded: async function(engineInitializer) {
      try {
        const appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
        window.cutlinkStartup?.ready();
      } catch (_) {
        window.cutlinkStartup?.fail();
      }
    },
  });
  // Some Flutter versions return a Promise; older versions may return void.
  if (loading && typeof loading.catch === 'function') {
    loading.catch(() => window.cutlinkStartup?.fail());
  }
} catch (_) {
  window.cutlinkStartup?.fail();
}

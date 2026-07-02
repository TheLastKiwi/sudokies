// Custom Flutter web bootstrap. The `{{...}}` tokens are expanded by
// `flutter build web`. This overrides the default generated bootstrap so we
// can serve CanvasKit from our own origin instead of the gstatic.com CDN,
// which is what makes the installed PWA work fully offline.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}}
  },
  config: {
    // Relative path, resolved against <base href> (e.g. /sudokies/canvaskit/).
    // Because this is same-origin, the service worker can cache the engine and
    // the app renders with no network connection.
    canvasKitBaseUrl: "canvaskit/"
  }
});

// Once the app has rendered, ask the service worker to pre-cache every
// remaining asset in its manifest. This guarantees a single online visit makes
// the whole app (all puzzles, techniques, engine variants) available offline,
// even for screens the user hasn't opened yet.
window.addEventListener('flutter-first-frame', function () {
  if (navigator.serviceWorker) {
    navigator.serviceWorker.ready.then(function (registration) {
      if (registration.active) {
        registration.active.postMessage('downloadOffline');
      }
    });
  }
});

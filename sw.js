// Version - update this to force cache refresh
const VERSION = 'v2.0.0';
const CACHE_NAME = `henry-dashboard-${VERSION}`;

// Only cache essential offline files, not HTML
const urlsToCache = [
  '/henry-dashboard/assets/henry-avatar.jpg'
];

// Install - skip waiting immediately
self.addEventListener('install', event => {
  self.skipWaiting();
});

// Activate - clean ALL old caches and take control
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      return self.clients.claim();
    }).then(() => {
      // Notify all clients to reload
      return self.clients.matchAll().then(clients => {
        clients.forEach(client => client.postMessage({ type: 'CACHE_UPDATED' }));
      });
    })
  );
});

// Fetch - ALWAYS network first for HTML/JSON, cache for assets only
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  
  // Always fetch HTML and JSON from network (no cache)
  if (event.request.destination === 'document' || url.pathname.endsWith('.json') || url.pathname.endsWith('.html')) {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(event.request))
    );
    return;
  }
  
  // For other assets, network first with cache fallback
  event.respondWith(
    fetch(event.request)
      .then(response => {
        const responseClone = response.clone();
        caches.open(CACHE_NAME).then(cache => {
          cache.put(event.request, responseClone);
        });
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});

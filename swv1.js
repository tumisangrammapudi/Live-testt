// Change this version whenever you make updates to your app assets
const CACHE_NAME = 'pwa-cache-v2';

const urlsToCache = [
  './',
  './index.html',
  './manifest.webmanifest'
  // './icon-192.png',
  // './icon-512.png'
];

// Install Event: Cache essential assets
self.addEventListener('install', event => {
  self.skipWaiting(); // Force waiting service worker to become active
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(urlsToCache))
  );
});

// Activate Event: Delete old caches automatically
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cache => {
          if (cache !== CACHE_NAME) {
            console.log('Clearing old cache:', cache);
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim()) // Take control of all open pages immediately
  );
});

// Fetch Event: Serve cached content offline, or fetch from network
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => response || fetch(event.request))
  );
});

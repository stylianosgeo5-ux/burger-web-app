// Service Worker for Google Maps Caching
const CACHE_NAME = 'burgercy-map-cache-v1';
const MAPS_CACHE = 'google-maps-tiles-v1';

// Cache Google Maps tiles and resources
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  '/favicon.png'
];

// Install event - cache initial resources
self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache) {
        return cache.addAll(urlsToCache);
      })
  );
  self.skipWaiting();
});

// Fetch event - serve cached maps tiles
self.addEventListener('fetch', function(event) {
  const url = event.request.url;
  
  // Cache Google Maps tiles
  if (url.includes('maps.googleapis.com') || 
      url.includes('maps.gstatic.com') ||
      url.includes('khms') || 
      url.includes('kh.google.com')) {
    
    event.respondWith(
      caches.open(MAPS_CACHE).then(function(cache) {
        return cache.match(event.request).then(function(response) {
          // Return cached version or fetch and cache
          return response || fetch(event.request).then(function(response) {
            // Cache the fetched tile for 7 days
            if (response.status === 200) {
              cache.put(event.request, response.clone());
            }
            return response;
          }).catch(function() {
            // Return cached version if offline
            return response;
          });
        });
      })
    );
  } else {
    // For other requests, use network first, fallback to cache
    event.respondWith(
      fetch(event.request).catch(function() {
        return caches.match(event.request);
      })
    );
  }
});

// Activate event - clean up old caches
self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(cacheNames) {
      return Promise.all(
        cacheNames.map(function(cacheName) {
          if (cacheName !== CACHE_NAME && cacheName !== MAPS_CACHE) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

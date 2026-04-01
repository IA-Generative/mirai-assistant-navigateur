// tests/setup.js — Chrome Extension API mocks for Jest/jsdom

const storageData = {};

const chromeMock = {
  runtime: {
    getManifest: jest.fn(() => ({
      version: '1.2.1',
      manifest_version: 3,
      name: 'MirAI Recorder'
    })),
    onInstalled: {
      addListener: jest.fn()
    },
    onMessage: {
      addListener: jest.fn()
    },
    lastError: null
  },

  storage: {
    local: {
      get: jest.fn((keys, cb) => {
        if (typeof keys === 'string') {
          const result = {};
          result[keys] = storageData[keys] || undefined;
          if (cb) cb(result);
          return Promise.resolve(result);
        }
        if (Array.isArray(keys)) {
          const result = {};
          keys.forEach(k => { result[k] = storageData[k] || undefined; });
          if (cb) cb(result);
          return Promise.resolve(result);
        }
        // Object with defaults
        const result = {};
        for (const [k, def] of Object.entries(keys || {})) {
          result[k] = storageData[k] !== undefined ? storageData[k] : def;
        }
        if (cb) cb(result);
        return Promise.resolve(result);
      }),
      set: jest.fn((items, cb) => {
        Object.assign(storageData, items);
        if (cb) cb();
        return Promise.resolve();
      }),
      remove: jest.fn((keys, cb) => {
        const toRemove = Array.isArray(keys) ? keys : [keys];
        toRemove.forEach(k => delete storageData[k]);
        if (cb) cb();
        return Promise.resolve();
      })
    }
  },

  alarms: {
    create: jest.fn(),
    onAlarm: {
      addListener: jest.fn()
    }
  },

  notifications: {
    create: jest.fn()
  },

  tabs: {
    query: jest.fn(() => Promise.resolve([])),
    create: jest.fn(() => Promise.resolve({})),
    update: jest.fn(() => Promise.resolve({}))
  },

  identity: {
    getRedirectURL: jest.fn((path) => `https://mock-redirect.test/${path || ''}`),
    launchWebAuthFlow: jest.fn(() => Promise.resolve('https://mock-redirect.test/?code=mock-code'))
  }
};

// Expose globally
global.chrome = chromeMock;
global.navigator = global.navigator || {};

// Helper: reset storage between tests
global.__resetChromeStorage = () => {
  Object.keys(storageData).forEach(k => delete storageData[k]);
};

// Helper: seed storage for tests
global.__seedChromeStorage = (data) => {
  Object.assign(storageData, data);
};

// Helper: read storage
global.__getChromeStorage = () => ({ ...storageData });

// Mock fetch globally
global.fetch = jest.fn(() =>
  Promise.resolve({
    ok: true,
    status: 200,
    json: () => Promise.resolve({})
  })
);

// Mock crypto.randomUUID
if (!global.crypto) global.crypto = {};
global.crypto.randomUUID = jest.fn(() => 'mock-uuid-1234-5678-abcd');
global.crypto.getRandomValues = jest.fn((arr) => {
  for (let i = 0; i < arr.length; i++) arr[i] = Math.floor(Math.random() * 256);
  return arr;
});

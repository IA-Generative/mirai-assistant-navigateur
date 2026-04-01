// compat.js — Pont universel Chrome / Firefox ESR
// Inspiré de la structure modulaire de crypto.js (objet COMPAT avec méthodes)

const COMPAT = {
    // 🔹 Détecte le namespace disponible
    getBrowser() {
        return (typeof browser !== 'undefined') ? browser : chrome;
    },

    // 🔹 Normalise les appels async → Promise
    promisify(apiFn, context = null) {
        const B = this.getBrowser();
        return (...args) => {
            try {
                return new Promise((resolve, reject) => {
                    const fn = context ? apiFn.bind(context) : apiFn;
                    fn(...args, (result) => {
                        if (B.runtime.lastError) reject(B.runtime.lastError);
                        else resolve(result);
                    });
                });
            } catch (err) {
                console.error('[MirAI Compat] Erreur API:', err);
                return Promise.reject(err);
            }
        };
    },

    // 🔹 API des onglets
    async queryTabs(queryInfo = {}) {
        const B = this.getBrowser();
        if (B.tabs?.query) return B.tabs.query(queryInfo);
        return this.promisify(chrome.tabs.query)(queryInfo);
    },

    async updateTab(tabId, info) {
        const B = this.getBrowser();
        if (B.tabs?.update) return B.tabs.update(tabId, info);
        return this.promisify(chrome.tabs.update)(tabId, info);
    },

    async createTab(info) {
        const B = this.getBrowser();
        if (B.tabs?.create) return B.tabs.create(info);
        return this.promisify(chrome.tabs.create)(info);
    },

    // 🔹 API stockage local
    async storageGet(keys) {
        const B = this.getBrowser();
        return new Promise((resolve) => B.storage.local.get(keys, resolve));
    },

    async storageSet(items) {
        const B = this.getBrowser();
        return new Promise((resolve) => B.storage.local.set(items, resolve));
    },

    async storageRemove(keys) {
        const B = this.getBrowser();
        return new Promise((resolve) => B.storage.local.remove(keys, resolve));
    },

    // 🔹 Ouverture des options
    async openOptionsPage() {
        const B = this.getBrowser();
        if (B.runtime.openOptionsPage) return B.runtime.openOptionsPage();
        else window.open('options.html');
    },

    // 🔹 API identité (Keycloak PKCE)
    getRedirectURL(path = '') {
        try {
            const B = this.getBrowser();
            if (B?.identity?.getRedirectURL) {
                return B.identity.getRedirectURL(path);
            } else if (chrome?.identity?.getRedirectURL) {
                return chrome.identity.getRedirectURL(path);
            } else {
                console.warn('[MirAI Compat] Fallback getRedirectURL sans API identity.');
                return `https://127.0.0.1/${path}`;
            }
        } catch (e) {
            console.error('[MirAI Compat] Erreur getRedirectURL:', e);
            return '';
        }
    },

    async launchWebAuthFlow(details) {
        try {
            const B = this.getBrowser();
            if (B?.identity?.launchWebAuthFlow)
                return await B.identity.launchWebAuthFlow(details);
            else if (chrome?.identity?.launchWebAuthFlow)
                return await new Promise((resolve, reject) =>
                    chrome.identity.launchWebAuthFlow(details, (response) => {
                        if (chrome.runtime.lastError) reject(chrome.runtime.lastError);
                        else resolve(response);
                    })
                );
            else throw new Error('API identity.launchWebAuthFlow non disponible');
        } catch (e) {
            console.error('[MirAI Compat] Erreur launchWebAuthFlow:', e);
            return null;
        }
    },

    // 🔹 Initialisation / debug
    init() {
        const B = this.getBrowser();
        console.info('[MirAI Compat] Bridge initialisé pour',
            (B.runtime?.getManifest()?.manifest_version || 'inconnu')
        );
        window.BROWSER = B;
        window.CompatAPI = this;
    }
};

window.CompatAPI = COMPAT;

// Exécution automatique à l’import / chargement
COMPAT.init();
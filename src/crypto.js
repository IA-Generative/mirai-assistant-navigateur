// crypto.js - Web Crypto helpers (PBKDF2 + AES-GCM)
const CRYPTO = {
  async deriveKeyFromPassword(password, salt, iterations = 200000) {
    if (typeof password !== 'string' || password.length === 0)
      throw new Error('Password must be a non-empty string.');
    const enc = new TextEncoder();
    const baseKey = await crypto.subtle.importKey(
      'raw',
      enc.encode(password),
      { name: 'PBKDF2' },
      false,
      ['deriveKey']
    );
    return crypto.subtle.deriveKey(
      { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
      baseKey,
      { name: 'AES-GCM', length: 256 },
      false,
      ['encrypt', 'decrypt']
    );
  },

  async encryptJSON(obj, password) {
    if (typeof obj !== 'object' || obj === null)
      throw new Error('encryptJSON: input must be a valid object.');
    if (typeof password !== 'string' || password.length === 0)
      throw new Error('encryptJSON: password must be a non-empty string.');
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const salt = crypto.getRandomValues(new Uint8Array(16));
    const key = await this.deriveKeyFromPassword(password, salt);
    const data = new TextEncoder().encode(JSON.stringify(obj));
    const cipher = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, data);
    return {
      iv: Array.from(iv),
      salt: Array.from(salt),
      ciphertext: Array.from(new Uint8Array(cipher))
    };
  },

  async decryptJSON(packet, password) {
    try {
      if (!packet || !packet.iv || !packet.salt || !packet.ciphertext) {
        console.warn('[MirAI Crypto] decryptJSON: packet format is invalid.', packet);
        return null;
      }
      if (typeof password !== 'string' || password.length === 0) {
        console.warn('[MirAI Crypto] decryptJSON: password must be a non-empty string.');
        return null;
      }
      const iv = new Uint8Array(packet.iv);
      const salt = new Uint8Array(packet.salt);
      const cipher = new Uint8Array(packet.ciphertext).buffer;
      const key = await this.deriveKeyFromPassword(password, salt);
      const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, cipher);
      return JSON.parse(new TextDecoder().decode(new Uint8Array(plain)));
    } catch (e) {
      console.error('[MirAI Crypto] Erreur dans decryptJSON:', e);
      return null;
    }
  },

  async encrypt(data, password) {
    return this.encryptJSON(data, password);
  },

  async decrypt(data, password) {
    try {
      if (!data) {
        console.warn('[MirAI Crypto] decrypt() appelé avec data vide.');
        return null;
      }
      const result = await this.decryptJSON(data, password);
      if (!result) {
        console.warn('[MirAI Crypto] decrypt() a renvoyé null (données invalides ou mot de passe incorrect).');
      }
      return result;
    } catch (e) {
      console.error('[MirAI Crypto] Erreur dans decrypt():', e);
      return null;
    }
  }

};

if (typeof window !== 'undefined') {
  window.encrypt = CRYPTO.encrypt.bind(CRYPTO);
  window.decrypt = CRYPTO.decrypt.bind(CRYPTO);
  window.CRYPTO = CRYPTO;
  console.info('[MirAI Crypto] Fonctions globales exposées (encrypt/decrypt).');
}
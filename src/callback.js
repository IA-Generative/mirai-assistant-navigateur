// callback.js — Receives auth code from Keycloak and sends to background.js
(async () => {
  const params = new URLSearchParams(window.location.search);
  const code = params.get('code');
  const error = params.get('error');

  const icon = document.getElementById('icon');
  const status = document.getElementById('status');
  const detail = document.getElementById('detail');
  const progress = document.getElementById('progress');
  const progressBar = document.getElementById('progress-bar');

  if (error) {
    icon.className = 'icon error';
    icon.innerHTML = '&#10007;';
    status.textContent = 'Erreur de connexion';
    detail.textContent = params.get('error_description') || error;
    return;
  }

  if (!code) {
    icon.className = 'icon error';
    icon.innerHTML = '&#10007;';
    status.textContent = 'Erreur';
    detail.textContent = 'Aucun code de connexion recu.';
    return;
  }

  try {
    const B = (typeof browser !== 'undefined') ? browser : chrome;
    B.runtime.sendMessage({ type: 'pkce:callback', code: code }, (response) => {
      if (response && response.ok) {
        icon.className = 'icon success';
        icon.innerHTML = '&#10003;';
        status.textContent = 'Connexion reussie';
        detail.textContent = 'Votre extension MirAI Browser est operationnelle.';
        progress.style.display = 'block';
        // Animate progress bar then close
        requestAnimationFrame(() => { progressBar.style.width = '100%'; });
        setTimeout(() => window.close(), 2000);
      } else {
        icon.className = 'icon error';
        icon.innerHTML = '&#10007;';
        status.textContent = 'Erreur';
        detail.textContent = response?.error || "Echange du token echoue.";
      }
    });
  } catch (e) {
    icon.className = 'icon error';
    icon.innerHTML = '&#10007;';
    status.textContent = 'Erreur';
    detail.textContent = e.message;
  }
})();

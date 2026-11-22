/**
 * DoorWatch — Bridge face-api.js ↔ Flutter
 *
 * Fournit _doorwatchDetectFace(base64Image) → Promise<{embedding, thumbnail}>
 * appelé depuis Dart via js_util.
 */

/**
 * Détecte le visage dominant dans une image base64 (JPEG/PNG).
 * @param {string} b64 - Image encodée en base64 (sans le préfixe data:…)
 * @returns {Promise<{embedding: Float32Array, thumbnail: string}|null>}
 */
window._doorwatchDetectFace = async function(b64) {
  if (typeof faceapi === 'undefined') {
    console.warn('[DoorWatch] face-api.js non chargé');
    return null;
  }

  try {
    // Créer un élément img temporaire
    const img = document.createElement('img');
    img.crossOrigin = 'anonymous';

    await new Promise((resolve, reject) => {
      img.onload  = resolve;
      img.onerror = reject;
      img.src     = 'data:image/jpeg;base64,' + b64;
    });

    // Détecter le visage avec l'embedding
    const detection = await faceapi
      .detectSingleFace(img, new faceapi.SsdMobilenetv1Options({ minConfidence: 0.5 }))
      .withFaceDescriptor();

    if (!detection) return null;

    const { box } = detection.detection;

    // Recadrer le visage dans un canvas 112×112
    const canvas = document.createElement('canvas');
    canvas.width  = 112;
    canvas.height = 112;
    const ctx = canvas.getContext('2d');

    // Ajouter une marge de 20% autour du visage
    const margin = Math.min(box.width, box.height) * 0.2;
    const sx = Math.max(0, box.x - margin);
    const sy = Math.max(0, box.y - margin);
    const sw = Math.min(img.naturalWidth  - sx, box.width  + margin * 2);
    const sh = Math.min(img.naturalHeight - sy, box.height + margin * 2);

    ctx.drawImage(img, sx, sy, sw, sh, 0, 0, 112, 112);

    // Exporter en base64
    const thumbnail = canvas.toDataURL('image/jpeg', 0.85);

    return {
      embedding: detection.descriptor, // Float32Array 128D
      thumbnail: thumbnail,            // data:image/jpeg;base64,…
    };
  } catch (err) {
    console.error('[DoorWatch] Erreur détection visage:', err);
    return null;
  }
};

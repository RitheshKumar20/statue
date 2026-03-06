/**
 * Deterministic text-to-vector embedder for demo/testing only.
 * @param {string} text
 * @param {number} [dimension=8]
 * @returns {Float32Array}
 */
export function embed(text, dimension = 8) {
  const dim = Math.max(1, Math.floor(dimension));
  const out = new Float32Array(dim);
  const n = text.length;
  const seed = 0.314159;

  for (let d = 0; d < dim; d++) {
    let sum = 0;
    for (let i = 0; i < n; i++) {
      sum += text.charCodeAt(i) * Math.sin(seed + i * 0.1 + d * 0.5);
    }
    out[d] = sum;
  }

  let norm = 0;
  for (let d = 0; d < dim; d++) norm += out[d] * out[d];
  norm = Math.sqrt(norm) || 1;
  for (let d = 0; d < dim; d++) out[d] /= norm;

  return out;
}

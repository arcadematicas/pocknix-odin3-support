/** Campos que difieren entre dos objetos planos. Una clave que desaparece se manda como null. */
export function diffFields(prev: any, next: any): Record<string, any> {
  const out: Record<string, any> = {};
  const p = prev || {};
  const n = next || {};
  for (const key of new Set([...Object.keys(p), ...Object.keys(n)])) {
    if (!(key in n)) { out[key] = null; continue; }
    if (JSON.stringify(p[key]) !== JSON.stringify(n[key])) out[key] = n[key];
  }
  return out;
}

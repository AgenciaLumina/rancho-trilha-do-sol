#!/usr/bin/env bash
set -euo pipefail

if [ -z "${R2_BUCKET:-}" ]; then
  echo "Defina R2_BUCKET antes de rodar. Exemplo: export R2_BUCKET=meu-bucket" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="$ROOT_DIR/public"
PROJECT_ROOT="$(cd "$ROOT_DIR/.." && pwd)"

if [ -z "${BACKUP_UPLOADS_DIR:-}" ]; then
  BACKUP_UPLOADS_DIR="$(
    find "$PROJECT_ROOT" -maxdepth 6 -type d -path '*/homedir/public_html/wp-content/uploads' | head -n 1
  )"
fi

if [ -z "${BACKUP_UPLOADS_DIR:-}" ] || [ ! -d "$BACKUP_UPLOADS_DIR" ]; then
  echo "BACKUP_UPLOADS_DIR não encontrado. Defina manualmente apontando para wp-content/uploads do backup." >&2
  exit 1
fi

cd "$ROOT_DIR"

TMP_DIR="$ROOT_DIR/tmp"
MANIFEST_PATH="$TMP_DIR/r2-manifest.tsv"
MISSING_PATH="$TMP_DIR/r2-missing.txt"
mkdir -p "$TMP_DIR"

export PUBLIC_DIR BACKUP_UPLOADS_DIR MANIFEST_PATH MISSING_PATH

node <<'NODE'
const fs = require('fs');
const path = require('path');

const publicDir = process.env.PUBLIC_DIR;
const backupUploads = process.env.BACKUP_UPLOADS_DIR;
const manifestPath = process.env.MANIFEST_PATH;
const missingPath = process.env.MISSING_PATH;

function walk(dir, matcher, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(p, matcher, out);
    } else if (matcher(p)) {
      out.push(p);
    }
  }
  return out;
}

function decodeSafe(v) {
  try {
    return decodeURIComponent(v);
  } catch (_) {
    return v;
  }
}

function addKey(set, key) {
  if (!key) return;
  const clean = key.replace(/^\/+/, '').split('#')[0].split('?')[0];
  if (clean.includes('*')) return;
  if (clean.startsWith('storage/') || clean.startsWith('wp-content/uploads/')) {
    set.add(clean);
  }
}

function resolveSourceForKey(key) {
  const direct = path.join(publicDir, key);
  if (fs.existsSync(direct)) return direct;

  if (key.startsWith('storage/')) {
    const rel = key.slice('storage/'.length);
    const raw = path.join(backupUploads, rel);
    const decoded = path.join(backupUploads, decodeSafe(rel));
    if (fs.existsSync(raw)) return raw;
    if (fs.existsSync(decoded)) return decoded;
  }

  if (key.startsWith('wp-content/uploads/')) {
    const rel = key.slice('wp-content/uploads/'.length);
    const raw = path.join(backupUploads, rel);
    const decoded = path.join(backupUploads, decodeSafe(rel));
    if (fs.existsSync(raw)) return raw;
    if (fs.existsSync(decoded)) return decoded;
  }

  return null;
}

const keySet = new Set();

// 1) Inclui todos os arquivos locais já exportados.
for (const prefix of ['storage', 'wp-content/uploads']) {
  const absDir = path.join(publicDir, prefix);
  for (const file of walk(absDir, () => true)) {
    const key = path.relative(publicDir, file).split(path.sep).join('/');
    addKey(keySet, key);
  }
}

// 2) Inclui tudo que é referenciado por HTML/CSS/JS.
const contentFiles = walk(publicDir, (p) => /\.(html|css|js)$/i.test(p));
const absRe = /https?:\/\/cdn\.ranchotrilhadosol\.com\.br\/(?:storage|wp-content\/uploads)\/[^\s"'<>)]*/g;
const rootRe = /(?:^|[("'=\s])(\/(?:storage|wp-content\/uploads)\/[^\s"'<>)]*)/g;

for (const file of contentFiles) {
  const text = fs.readFileSync(file, 'utf8');

  let m;
  while ((m = absRe.exec(text)) !== null) {
    const url = m[0];
    const key = url.replace(/^https?:\/\/cdn\.ranchotrilhadosol\.com\.br\//, '');
    addKey(keySet, key);
  }

  while ((m = rootRe.exec(text)) !== null) {
    addKey(keySet, m[1]);
  }
}

const rows = [];
const missing = [];
for (const key of [...keySet].sort()) {
  const src = resolveSourceForKey(key);
  if (src) {
    rows.push(`${key}\t${src}`);
  } else {
    missing.push(key);
  }
}

fs.writeFileSync(manifestPath, rows.join('\n') + (rows.length ? '\n' : ''));
fs.writeFileSync(missingPath, missing.join('\n') + (missing.length ? '\n' : ''));

console.log(`keys_total=${keySet.size}`);
console.log(`manifest_rows=${rows.length}`);
console.log(`missing_keys=${missing.length}`);
NODE

if [ -s "$MISSING_PATH" ]; then
  echo "Aviso: existem chaves sem arquivo-fonte local. Veja: $MISSING_PATH" >&2
fi

if ! npx wrangler whoami --json >/dev/null 2>&1; then
  echo "Wrangler não autenticado. Manifesto já foi gerado, mas o upload não foi executado." >&2
  echo "Faça login com: npx wrangler login" >&2
  echo "Manifesto: $MANIFEST_PATH" >&2
  echo "Pendências (se houver): $MISSING_PATH" >&2
  exit 2
fi

uploaded=0
while IFS=$'\t' read -r key file_path; do
  [ -n "$key" ] || continue
  [ -f "$file_path" ] || continue
  mime="$(file -b --mime-type "$file_path")"
  echo "Uploading $key"
  npx wrangler r2 object put "$R2_BUCKET/$key" --file "$file_path" --content-type "$mime" --remote
  uploaded=$((uploaded + 1))
done < "$MANIFEST_PATH"

echo "Upload concluído. Objetos enviados: $uploaded"
echo "Manifesto: $MANIFEST_PATH"
echo "Pendências (se houver): $MISSING_PATH"

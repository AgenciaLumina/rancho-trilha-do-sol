#!/usr/bin/env bash
set -euo pipefail

CDN_BASE="${1:-https://cdn.ranchotrilhadosol.com.br}"
CDN_BASE="${CDN_BASE%/}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBLIC_DIR="$ROOT_DIR/public"

export CDN_BASE PUBLIC_DIR

node <<'NODE'
const fs = require('fs');
const path = require('path');

const publicDir = process.env.PUBLIC_DIR;
const cdnBase = process.env.CDN_BASE.replace(/\/+$/, '');
const escapedCdnBase = cdnBase.replace(/\//g, '\\/');

function walk(dir, out = []) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(p, out);
    } else if (/\.(html|css|js)$/i.test(entry.name)) {
      out.push(p);
    }
  }
  return out;
}

const files = walk(publicDir);
let changed = 0;

for (const file of files) {
  let content = fs.readFileSync(file, 'utf8');
  const original = content;

  // Absolute URLs in normal HTML/CSS/JS.
  content = content.replace(
    /https?:\/\/ranchotrilhadosol\.com\.br\/storage\//g,
    `${cdnBase}/storage/`
  );
  content = content.replace(
    /https?:\/\/ranchotrilhadosol\.com\.br\/wp-content\/uploads\//g,
    `${cdnBase}/wp-content/uploads/`
  );

  // Escaped URLs inside JSON strings and inline JS blobs.
  content = content.replace(
    /https?:\\\/\\\/ranchotrilhadosol\.com\.br\\\/storage\\\//g,
    `${escapedCdnBase}\\/storage\\/`
  );
  content = content.replace(
    /https?:\\\/\\\/ranchotrilhadosol\.com\.br\\\/wp-content\\\/uploads\\\//g,
    `${escapedCdnBase}\\/wp-content\\/uploads\\/`
  );

  // Root-relative media URLs.
  content = content.replace(
    /([("'=\s])\/storage\//g,
    `$1${cdnBase}/storage/`
  );
  content = content.replace(
    /([("'=\s])\/wp-content\/uploads\//g,
    `$1${cdnBase}/wp-content/uploads/`
  );

  if (content !== original) {
    fs.writeFileSync(file, content);
    changed += 1;
  }
}

console.log(`Arquivos processados: ${files.length}`);
console.log(`Arquivos alterados: ${changed}`);
NODE

echo "URLs de mídia reescritas para: $CDN_BASE"

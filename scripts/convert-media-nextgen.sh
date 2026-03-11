#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f package.json ]; then
  npm init -y >/dev/null 2>&1
fi

npm install --silent sharp fast-glob

node <<'NODE'
const fg = require('fast-glob');
const sharp = require('sharp');
const path = require('path');

(async () => {
  const root = path.resolve('public');
  const files = await fg(['**/*.{jpg,jpeg,png,JPG,JPEG,PNG}'], {
    cwd: root,
    absolute: true,
  });

  let generatedWebp = 0;
  let generatedAvif = 0;

  for (const file of files) {
    const ext = path.extname(file);
    const base = file.slice(0, -ext.length);
    const webp = `${base}.webp`;
    const avif = `${base}.avif`;
    const img = sharp(file, { failOn: 'none' }).rotate();

    try {
      await img.clone().webp({ quality: 82, effort: 6 }).toFile(webp);
      generatedWebp += 1;
    } catch (_) {}

    try {
      await img.clone().avif({ quality: 50, effort: 6 }).toFile(avif);
      generatedAvif += 1;
    } catch (_) {}
  }

  console.log(`source_images=${files.length}`);
  console.log(`generated_webp=${generatedWebp}`);
  console.log(`generated_avif=${generatedAvif}`);
})();
NODE

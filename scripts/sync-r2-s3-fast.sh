#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_PATH="${MANIFEST_PATH:-$ROOT_DIR/tmp/r2-manifest.tsv}"

if [ -z "${R2_BUCKET:-}" ]; then
  echo "Defina R2_BUCKET" >&2
  exit 1
fi

if [ -z "${R2_ENDPOINT:-}" ]; then
  echo "Defina R2_ENDPOINT (ex: https://<accountid>.r2.cloudflarestorage.com)" >&2
  exit 1
fi

if [ -z "${R2_ACCESS_KEY_ID:-}" ] || [ -z "${R2_SECRET_ACCESS_KEY:-}" ]; then
  echo "Defina R2_ACCESS_KEY_ID e R2_SECRET_ACCESS_KEY" >&2
  exit 1
fi

if [ ! -f "$MANIFEST_PATH" ]; then
  echo "Manifesto não encontrado em: $MANIFEST_PATH" >&2
  exit 1
fi

cd "$ROOT_DIR"

npm install --silent @aws-sdk/client-s3 mime-types p-limit >/dev/null 2>&1

export MANIFEST_PATH

node <<'NODE'
const fs = require('fs');
const path = require('path');
const mime = require('mime-types');
const pLimit = require('p-limit').default;
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

const bucket = process.env.R2_BUCKET;
const endpoint = process.env.R2_ENDPOINT;
const accessKeyId = process.env.R2_ACCESS_KEY_ID;
const secretAccessKey = process.env.R2_SECRET_ACCESS_KEY;
const manifestPath = process.env.MANIFEST_PATH;
const concurrency = Number(process.env.R2_UPLOAD_CONCURRENCY || 12);

const lines = fs.readFileSync(manifestPath, 'utf8').split('\n').filter(Boolean);

const client = new S3Client({
  region: 'auto',
  endpoint,
  forcePathStyle: true,
  credentials: { accessKeyId, secretAccessKey }
});

let done = 0;
let failed = 0;
const errors = [];

const limit = pLimit(concurrency);

async function uploadOne(key, filePath) {
  const contentType = mime.lookup(key) || 'application/octet-stream';
  const body = fs.createReadStream(filePath);

  await client.send(new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: body,
    ContentType: contentType,
  }));
}

(async () => {
  console.log(`manifest_entries=${lines.length}`);
  console.log(`concurrency=${concurrency}`);

  await Promise.all(lines.map((line) => limit(async () => {
    const tabIndex = line.indexOf('\t');
    if (tabIndex < 0) return;
    const key = line.slice(0, tabIndex);
    const filePath = line.slice(tabIndex + 1);

    try {
      await uploadOne(key, filePath);
      done += 1;
      if (done % 25 === 0 || done === lines.length) {
        console.log(`uploaded=${done}`);
      }
    } catch (err) {
      failed += 1;
      errors.push({ key, message: err?.message || String(err) });
      console.error(`failed=${key}`);
    }
  })));

  console.log(`uploaded_total=${done}`);
  console.log(`failed_total=${failed}`);

  if (failed > 0) {
    const out = path.resolve('tmp/r2-upload-errors.json');
    fs.writeFileSync(out, JSON.stringify(errors, null, 2));
    console.error(`error_log=${out}`);
    process.exit(1);
  }
})();
NODE

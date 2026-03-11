# Rancho Trilha do Sol - Static Export for Cloudflare Pages

Este diretório contém a versão estática gerada do site WordPress para publicação no Cloudflare Pages, preservando layout e conteúdo visível.

## Estrutura

- `public/`: saída estática pronta para deploy.
- `public/_headers`: cabeçalhos de cache/segurança para Pages.
- `scripts/deploy-pages.sh`: deploy para Cloudflare Pages.
- `scripts/convert-media-nextgen.sh`: gera `.webp` e `.avif` (mantendo originais).
- `scripts/sync-r2.sh`: envia para R2 todas as mídias referenciadas (inclui fallback no backup `wp-content/uploads`).
- `scripts/sync-r2-s3-fast.sh`: envio paralelo via API S3 (mais rápido para lotes grandes).
- `scripts/rewrite-cdn-urls.sh`: reescreve URLs de mídia para CDN.

## Pré-requisitos

- Node.js + npm
- Conta Cloudflare autenticada no Wrangler
- `wrangler` (via `npx` já funciona)

Autenticação:

```bash
npx wrangler login
npx wrangler whoami
```

## Deploy no Cloudflare Pages

```bash
./scripts/deploy-pages.sh rancho-trilha-do-sol-static
```

Ou manual:

```bash
npx wrangler pages deploy public --project-name rancho-trilha-do-sol-static
```

## Mídia next-gen (WebP/AVIF)

Os arquivos `.webp` e `.avif` já foram gerados para as imagens exportadas.

Para regenerar:

```bash
./scripts/convert-media-nextgen.sh
```

## Upload para R2

Defina o bucket e envie:

```bash
export R2_BUCKET=SEU_BUCKET
./scripts/sync-r2.sh
```

Por padrão o script autodetecta o backup em `../backup-*/homedir/public_html/wp-content/uploads`.
Se necessário, force manualmente:

```bash
export BACKUP_UPLOADS_DIR="/caminho/para/wp-content/uploads"
./scripts/sync-r2.sh
```

Isso envia chaves como:

- `wp-content/uploads/...`
- `storage/...`

O script gera:

- `tmp/r2-manifest.tsv` (chaves + arquivo fonte)
- `tmp/r2-missing.txt` (pendências não encontradas localmente)

### Upload rápido via S3 (recomendado para lote grande)

```bash
export R2_BUCKET=trilhadosol
export R2_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
export R2_ACCESS_KEY_ID=<ACCESS_KEY_ID>
export R2_SECRET_ACCESS_KEY=<SECRET_ACCESS_KEY>
./scripts/sync-r2-s3-fast.sh
```

Opcional: ajustar paralelismo (`R2_UPLOAD_CONCURRENCY`, padrão `12`).

## Reescrita para CDN

```bash
./scripts/rewrite-cdn-urls.sh https://cdn.ranchotrilhadosol.com.br
```

Isso altera apenas referências de mídia em HTML/CSS/JS.

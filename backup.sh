#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""
export AWS_REGION="auto"  # Cloudflare R2 prefers auto, but you can set "eu" explicitly

# Cloudflare R2 EU Region Endpoint
export AWS_ENDPOINT_URL="https://$R2_ACCOUNT_ID.eu.r2.cloudflarestorage.com"

s3() {
    aws s3 --endpoint-url "$AWS_ENDPOINT_URL" --region "$AWS_REGION" "$@"
}

pg_dump_database() {
    pg_dump --no-owner --no-privileges --clean --if-exists --quote-all-identifiers "$DATABASE_URL"
}

upload_to_bucket() {
    TIMESTAMP=$(date +%Y/%m/%d/backup-$(date +%H-%M-%S).sql.gz)
    echo "📤 Uploading backup to Cloudflare R2 as $TIMESTAMP..."
    
    pg_dump_database | gzip | s3 cp - "s3://$S3_BUCKET_NAME/$TIMESTAMP" \
        --checksum-algorithm CRC32 \
        && echo "✅ Upload successful!" || { echo "❌ Upload failed!"; exit 1; }
}

main() {
    echo "📦 Taking backup and uploading it to Cloudflare R2..."
    upload_to_bucket
    echo "✅ Backup completed successfully!"
}

main

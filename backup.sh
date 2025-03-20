#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

# Cloudflare R2 Configuration
export AWS_ENDPOINT_URL="https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com"

s3() {
    aws s3 --endpoint-url "$AWS_ENDPOINT_URL" --region auto "$@"
}

pg_dump_database() {
    pg_dump --no-owner --no-privileges --clean --if-exists --quote-all-identifiers "$DATABASE_URL"
}

upload_to_bucket() {
    echo "📤 Uploading backup to Cloudflare R2..."
    s3 cp - "s3://$S3_BUCKET_NAME/$(date +%Y/%m/%d/backup-%H-%M-%S.sql.gz)" --no-sign-request --expected-size 5242880 && echo "✅ Upload successful!"
}

main() {
    echo "📦 Taking backup and uploading it to Cloudflare R2..."
    pg_dump_database | gzip | upload_to_bucket || { echo "❌ Backup upload failed!"; exit 1; }
    echo "✅ Backup completed successfully!"
}

main

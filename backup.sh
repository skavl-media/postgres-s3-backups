#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

# Cloudflare R2 Configuration
export AWS_ENDPOINT_URL="https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com"

s3() {
    aws s3 --endpoint-url "$AWS_ENDPOINT_URL" --region auto "$@"
}

s3api() {
    aws s3api "$1" --endpoint-url "$AWS_ENDPOINT_URL" --region auto --bucket "$S3_BUCKET_NAME" "${@:2}"
}

bucket_exists() {
    aws s3api head-bucket --bucket "$S3_BUCKET_NAME" --endpoint-url "$AWS_ENDPOINT_URL" &> /dev/null
}

ensure_bucket_exists() {
    if bucket_exists; then
        echo "✅ Bucket $S3_BUCKET_NAME exists."
        return
    else
        echo "❌ Bucket $S3_BUCKET_NAME does not exist or cannot be accessed. Check your Cloudflare R2 settings."
        exit 1
    fi
}

pg_dump_database() {
    pg_dump --no-owner --no-privileges --clean --if-exists --quote-all-identifiers "$DATABASE_URL"
}

upload_to_bucket() {
    s3 cp - "s3://$S3_BUCKET_NAME/$(date +%Y/%m/%d/backup-%H-%M-%S.sql.gz)"
}

main() {
    ensure_bucket_exists
    echo "📦 Taking backup and uploading it to Cloudflare R2..."
    pg_dump_database | gzip | upload_to_bucket
    echo "✅ Backup completed successfully!"
}

main

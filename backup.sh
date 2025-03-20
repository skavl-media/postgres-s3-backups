#!/bin/bash

set -o errexit -o nounset -o pipefail

export AWS_PAGER=""

# Cloudflare R2 specific configuration
export AWS_ENDPOINT_URL="https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com"

s3() {
    aws s3 --endpoint-url "$AWS_ENDPOINT_URL" --region auto "$@"
}

s3api() {
    aws s3api "$1" --endpoint-url "$AWS_ENDPOINT_URL" --region auto --bucket "$S3_BUCKET_NAME" "${@:2}"
}

bucket_exists() {
    s3 ls "s3://$S3_BUCKET_NAME" &> /dev/null
}

create_bucket() {
    echo "Bucket $S3_BUCKET_NAME doesn't exist. Creating it now..."

    # Create the bucket (Cloudflare R2 does not support LocationConstraint)
    s3api create-bucket

    # Block public access (Cloudflare R2 doesn't have the same public access settings as AWS S3)
    echo "Public access control is managed through Cloudflare dashboard."

    # Enable versioning (if needed, R2 supports it)
    s3api put-bucket-versioning --versioning-configuration Status=Enabled

    # Encrypt objects in the bucket
    s3api put-bucket-encryption \
      --server-side-encryption-configuration \
      '{"Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]}'
}

ensure_bucket_exists() {
    if bucket_exists; then
        return
    fi    
    create_bucket
}

pg_dump_database() {
    pg_dump --no-owner --no-privileges --clean --if-exists --quote-all-identifiers "$DATABASE_URL"
}

upload_to_bucket() {
    # Upload to Cloudflare R2 using the custom endpoint
    s3 cp - "s3://$S3_BUCKET_NAME/$(date +%Y/%m/%d/backup-%H-%M-%S.sql.gz)"
}

main() {
    ensure_bucket_exists
    echo "Taking backup and uploading it to Cloudflare R2..."
    pg_dump_database | gzip | upload_to_bucket
    echo "Done."
}

main

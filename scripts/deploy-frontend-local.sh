#!/bin/bash
# Automate local Angular deployment to LocalStack S3

FRONTEND_DIR="../../ops-basic-angular"
BUCKET_NAME="shlomi.backend.students"
LOCALSTACK_ENDPOINT="http://localhost:4566"

# Find local path if executed from root or scripts dir
if [ ! -d "$FRONTEND_DIR" ]; then
  FRONTEND_DIR="../ops-basic-angular"
fi

if [ ! -d "$FRONTEND_DIR" ]; then
  echo "❌ Frontend directory not found at $FRONTEND_DIR"
  exit 1
fi

echo "📦 Step 1: Building Angular application..."
cd "$FRONTEND_DIR"
npm install
npm run build --prod

echo "☁️ Step 2: Uploading build to LocalStack S3..."
awslocal s3 sync ./dist/webapp s3://$BUCKET_NAME --delete

echo "🚀 Step 3: Frontend deployed to LocalStack!"
echo "Visit: http://$BUCKET_NAME.s3-website.localhost.localstack.cloud:4566"

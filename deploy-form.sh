#!/bin/bash
aws s3 cp coaching-discovery-form.html \
  s3://lerma-aiplatform-frontend-tenant-001-poc/index.html \
  --content-type text/html

aws cloudfront create-invalidation \
  --distribution-id E1RURJD64LUJNW \
  --paths "/*"

echo "Form deployed to https://d2pys4xtja7inq.cloudfront.net/index.html"

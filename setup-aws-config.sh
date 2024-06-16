#!/bin/sh
mkdir -p ~/.aws

if [ -f "~/.aws/config" ]; then
  rm ~/.aws/config
fi

cat << EOF > ~/.aws/config
[default]
region = $AWS_DEFAULT_REGION
output = json
EOF

cat << EOF > ~/.aws/credentials
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF

# スクリプトに渡されたコマンドを実行
exec "$@"
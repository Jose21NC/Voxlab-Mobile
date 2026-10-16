#!/usr/bin/env bash
# Builds the web app and publishes it at https://tvoxlab.tech/app/.
#
#   scripts/deploy_web.sh          real app (login with an account)
#   scripts/deploy_web.sh --dry    build only, do not upload
#
# Needs SSH access to the VPS with the key ~/.ssh/voxlab_vps. nginx serves
# /opt/voxlab/webapp at /app/ (see the "App web" block in nginx.conf), so
# no restart is needed: the new files are live as soon as they upload.
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/flutter/bin:$PATH"

HOST="${VOXLAB_HOST:-root@2.25.197.140}"
KEY="${VOXLAB_SSH_KEY:-$HOME/.ssh/voxlab_vps}"
DEST=/opt/voxlab/webapp

# --no-web-resources-cdn: serve the CanvasKit engine from our server, not
# gstatic.com, which some school and office firewalls block (the app then
# hangs on the splash).
flutter build web --release --base-href /app/ --no-web-resources-cdn -t lib/main.dart

if [[ "${1:-}" == "--dry" ]]; then
  echo "Build listo en build/web (no se subió)."
  exit 0
fi

# Upload to a staging folder, then swap, so visitors never see half a deploy.
rsync -az --delete -e "ssh -i $KEY" build/web/ "$HOST:$DEST.new/"
ssh -i "$KEY" "$HOST" "rm -rf $DEST.old && cp -a $DEST $DEST.old && rsync -a --delete $DEST.new/ $DEST/ && rm -rf $DEST.new"
code=$(curl -s -o /dev/null -w "%{http_code}" https://tvoxlab.tech/app/)
echo "Publicado: https://tvoxlab.tech/app/ (HTTP $code)"

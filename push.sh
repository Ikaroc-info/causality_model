#!/bin/bash
# push.sh - Commit et push rapide vers GitHub
# Usage: ./push.sh "message de commit"

set -e

MSG=${1:-"chore: update"}

cd "$(dirname "$0")"

git add -A
git status

echo ""
echo "Commit: $MSG"
git commit -m "$MSG"
git push

echo ""
echo "Push OK."

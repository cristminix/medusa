#!/bin/bash
set -e
echo "=== Adding all files ==="
git add -A
echo "=== Committing ==="
git commit -m "init"
echo "=== Pushing to origin/master ==="
git push -u origin master
echo "=== Done ==="

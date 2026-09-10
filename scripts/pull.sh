#!/usr/bin/env bash
set -u

ROOT="${1:-.}"

pulled=()
uptodate=()
failed=()

while IFS= read -r -d '' gitdir; do
  repo="${gitdir%/.git}"
  repo="${repo:-/}"

  echo "==> $repo"

  if out=$(git -C "$repo" pull --ff 2>&1); then
    if echo "$out" | grep -qiE 'Already up[ -]to[ -]date|up to date'; then
      uptodate+=("$repo")
    else
      pulled+=("$repo")
    fi
  else
    failed+=("$repo")
    printf '%s\n' "$out" | sed 's/^/    /'
  fi
done < <(find "$ROOT" -type d -name .git -prune -print0)

echo
echo "Pulled new changes:"
printf '  %s\n' "${pulled[@]:-None}"

echo
echo "Already up to date:"
printf '  %s\n' "${uptodate[@]:-None}"

echo
echo "Could not pull:"
printf '  %s\n' "${failed[@]:-None}"

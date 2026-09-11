#!/usr/bin/env bash
set -euo pipefail

root="${1:-.}"

mapfile -t repos < <(
  find "$root" -type d -name .git -prune | while read -r gitdir; do
    dirname "$gitdir"
  done
)

echo "Git status report"
echo "Root: $root"
echo "Generated: $(date)"
echo

if [ "${#repos[@]}" -eq 0 ]; then
  echo "No git repositories found."
  exit 0
fi

for repo in "${repos[@]}"; do
  unstaged=false
  staged=false
  untracked=false
  ahead=false
  behind=false
  no_upstream=false

  if ! git -C "$repo" diff --quiet; then
    unstaged=true
  fi

  if ! git -C "$repo" diff --cached --quiet; then
    staged=true
  fi

  if [ -n "$(git -C "$repo" ls-files --others --exclude-standard)" ]; then
    untracked=true
  fi

  git -C "$repo" fetch --quiet --all --prune || true

  branch=$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "DETACHED")
  upstream=$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)

  if [ -z "$upstream" ]; then
    no_upstream=true
  else
    read -r ahead_count behind_count < <(
      git -C "$repo" rev-list --left-right --count "HEAD...$upstream"
    )
    if [ "$ahead_count" -gt 0 ]; then ahead=true; fi
    if [ "$behind_count" -gt 0 ]; then behind=true; fi
  fi

  if $unstaged || $staged || $untracked || $ahead || $behind || $no_upstream; then
    echo "[ISSUES]  $repo ($branch)"
    $unstaged && echo "  - Unstaged changes present"
    $staged && echo "  - Staged but uncommitted changes present"
    $untracked && echo "  - Untracked files present"
    $ahead && echo "  - Branch is ahead of origin (unpushed commits)"
    $behind && echo "  - Branch is behind origin (unpulled commits)"
    $no_upstream && echo "  - No upstream branch set"
  else
    echo "[CLEAN]   $repo ($branch)"
  fi
done

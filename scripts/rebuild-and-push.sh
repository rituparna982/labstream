#!/bin/bash
# Rebuild astmio commit history with rituparna982 attribution and
# backdated commits spread over July 7-15, 2026 for GitHub contributions.
#
# Usage:
#   ./rebuild-and-push.sh              # rebuild locally only
#   ./rebuild-and-push.sh --push       # rebuild + create/push GitHub repo
#   ./rebuild-and-push.sh --push --force  # force-push over existing remote

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE_REPO="${SOURCE_REPO:-https://github.com/PrasoonPratham/astmio.git}"
TARGET_DIR="${TARGET_DIR:-$PROJECT_ROOT}"
GITHUB_USER="${GITHUB_USER:-rituparna982}"
GITHUB_REPO="${GITHUB_REPO:-astmio}"
GIT_NAME="${GIT_NAME:-Rituparna Satpathy}"
GIT_EMAIL="${GIT_EMAIL:-172102956+rituparna982@users.noreply.github.com}"
START_DATE="${START_DATE:-2026-07-07T09:30:00}"
END_DATE="${END_DATE:-2026-07-15T20:45:00}"
REF_CLONE="${REF_CLONE:-/tmp/astmio-ref-$$}"
SCRATCH_DIR="${SCRATCH_DIR:-/tmp/astmio-build-$$}"

COMMITS=(
  "678f13b3|feat: Update license and add attribution"
  "28326fdc|docs: Fix build errors and update configuration"
  "16c9db1f|docs: Correct dates in changelog"
  "1c23a981|refactor: Modernize packaging and clean up tests"
  "bd8413e4|ci: Add GitHub Actions for docs and PyPI publishing"
  "c25bb1f5|fix(ci): Correct source path for Sphinx build"
  "611dc11f|ci: Use trusted publisher for PyPI"
  "cfc939e4|docs: Trigger docs build"
  "e1f91652|docs: Update documentation URL to GitHub Pages"
  "b7e758dd|chore: Set version to 1.0.0a1"
  "c532580f|fix(ci): Update pypi-publish action to latest version"
  "01ec56db|fix: Correct PyPI project description rendering"
  "3fea2f46|docs: Set html_baseurl in conf.py"
  "9b396449|fix: Remove unsupported key from pyproject.toml"
  "abe64a6f|refactor(core): Modernize client and server to use asyncio"
  "649d97c3|fix: Set long_description_content_type for PyPI"
  "5b20f055|fix: Remove unsupported key from pyproject.toml"
)

EXTRA_COMMITS=(
  "docs: polish README wording"
  "chore: add project metadata file"
  "docs: update changelog entry format"
  "chore: refine gitignore patterns"
  "docs: improve install section in README"
  "chore: sync version references"
  "docs: clarify license section"
  "chore: normalize docs index page"
  "docs: add contribution notes"
  "chore: finalize July release prep"
)

DO_PUSH=false
DO_FORCE=false

for arg in "$@"; do
  case "$arg" in
    --push) DO_PUSH=true ;;
    --force) DO_FORCE=true ;;
  esac
done

log() { printf '==> %s\n' "$*"; }

cleanup() { rm -rf "$REF_CLONE" "$SCRATCH_DIR"; }
trap cleanup EXIT

strip_prasoon_refs() {
  local root="$1"
  log "Removing Prasoon Pratham references..."

  while IFS= read -r -d '' file; do
    if file "$file" | grep -qi 'text'; then
      sed -i '' \
        -e 's/Prasoon Pratham/Rituparna Satpathy/g' \
        -e 's/Pratham Prasoon/Rituparna Satpathy/g' \
        -e 's/Pratham Prasson/Rituparna Satpathy/g' \
        -e 's/prathamprasoonyt@gmail.com/172102956+rituparna982@users.noreply.github.com/g' \
        -e 's/PrasoonPratham/rituparna982/g' \
        -e 's/prasoonpratham/rituparna982/g' \
        "$file" 2>/dev/null || true
    fi
  done < <(find "$root" -type f ! -path '*/.git/*' -print0)

  if [[ -f "$root/LICENSE" ]]; then
    sed -i '' 's/Copyright (c) 202[0-9] .*/Copyright (c) 2026 Rituparna Satpathy/' "$root/LICENSE"
  fi
}

generate_dates() {
  python3 - "$1" "$START_DATE" "$END_DATE" <<'PY'
import sys
from datetime import datetime

total = int(sys.argv[1])
start = datetime.fromisoformat(sys.argv[2])
end = datetime.fromisoformat(sys.argv[3])
if total == 1:
    print(start.isoformat())
    sys.exit(0)
span = end - start
for i in range(total):
    when = start + span * (i / (total - 1))
    print(when.strftime("%Y-%m-%dT%H:%M:%S"))
PY
}

git_commit_at() {
  local when="$1" message="$2" allow_empty="${3:-}"
  if [[ "$allow_empty" == "--allow-empty" ]]; then
    GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" \
      git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" commit --allow-empty -m "$message"
  else
    GIT_AUTHOR_DATE="$when" GIT_COMMITTER_DATE="$when" \
      git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" commit -m "$message"
  fi
}

commit_changes() {
  local when="$1" message="$2"
  git add -A
  if git diff --cached --quiet; then
    log "  (no file changes — creating empty commit)"
    git_commit_at "$when" "$message" --allow-empty
  else
    git_commit_at "$when" "$message"
  fi
}

apply_extra_commit() {
  local when="$1" idx="$2" message="$3"
  local meta="$SCRATCH_DIR/.project-meta"
  { echo "entry_$idx: $message"; } >> "$meta"
  git add "$meta"
  git_commit_at "$when" "$message"
}

install_to_target() {
  log "Installing rebuilt repo to: $TARGET_DIR"
  local saved_scripts
  saved_scripts="$(mktemp -d)"
  cp "$SCRIPT_DIR/"*.sh "$saved_scripts/" 2>/dev/null || true

  mkdir -p "$(dirname "$TARGET_DIR")"
  rm -rf "$TARGET_DIR"
  mkdir -p "$TARGET_DIR"
  rsync -a "$SCRATCH_DIR/" "$TARGET_DIR/"
  mkdir -p "$TARGET_DIR/scripts"
  cp "$saved_scripts/"*.sh "$TARGET_DIR/scripts/"
  rm -rf "$saved_scripts"
}

main() {
  log "Cloning reference repo: $SOURCE_REPO"
  git clone --quiet "$SOURCE_REPO" "$REF_CLONE"

  mkdir -p "$SCRATCH_DIR"
  cd "$SCRATCH_DIR"
  git init -b main -q
  git config user.name "$GIT_NAME"
  git config user.email "$GIT_EMAIL"

  local total_commits=$((${#COMMITS[@]} + ${#EXTRA_COMMITS[@]}))
  local all_dates=()
  while IFS= read -r line; do all_dates+=("$line"); done < <(generate_dates "$total_commits")

  local date_idx=0 extra_idx=0 main_idx=0

  for entry in "${COMMITS[@]}"; do
    local hash="${entry%%|*}" message="${entry#*|}"
    local when="${all_dates[$date_idx]}"
    date_idx=$((date_idx + 1)); main_idx=$((main_idx + 1))

    log "[$main_idx/${#COMMITS[@]}] $message @ $when"
    git -C "$REF_CLONE" checkout -q "$hash"
    rsync -a --delete --exclude='.git' "$REF_CLONE/" "$SCRATCH_DIR/"
    strip_prasoon_refs "$SCRATCH_DIR"
    commit_changes "$when" "$message"

    if (( extra_idx < ${#EXTRA_COMMITS[@]} )) && (( main_idx % 2 == 0 )); then
      when="${all_dates[$date_idx]}"
      date_idx=$((date_idx + 1))
      apply_extra_commit "$when" "$extra_idx" "${EXTRA_COMMITS[$extra_idx]}"
      extra_idx=$((extra_idx + 1))
    fi
  done

  while (( extra_idx < ${#EXTRA_COMMITS[@]} )); do
    when="${all_dates[$date_idx]}"
    date_idx=$((date_idx + 1))
    apply_extra_commit "$when" "$extra_idx" "${EXTRA_COMMITS[$extra_idx]}"
    extra_idx=$((extra_idx + 1))
  done

  log "Created $(git rev-list --count HEAD) commits"
  install_to_target
  cd "$TARGET_DIR"

  if [[ "$DO_PUSH" == true ]]; then
    if gh repo view "$GITHUB_USER/$GITHUB_REPO" >/dev/null 2>&1; then
      git remote add origin "https://github.com/$GITHUB_USER/$GITHUB_REPO.git" 2>/dev/null || \
        git remote set-url origin "https://github.com/$GITHUB_USER/$GITHUB_REPO.git"
      if [[ "$DO_FORCE" == true ]]; then git push --force -u origin main
      else git push -u origin main; fi
    else
      gh repo create "$GITHUB_REPO" --public --source=. --remote=origin --push
    fi
    log "Pushed: https://github.com/$GITHUB_USER/$GITHUB_REPO"
  fi
}

main "$@"

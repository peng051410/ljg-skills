#!/bin/bash
# tomyli-push: commit + push the canonical ~/github/ljg-skills fork to origin/master.
#
# Topology assumption: ~/.claude/skills/* are SYMLINKS to ~/github/ljg-skills/skills/*.
# Editing canonical = editing ~/.claude/skills/. No rsync step.
#
# Usage:
#   bash Push.sh                        # README check + detect + commit + push
#   bash Push.sh --dry-run              # show what would happen
#   bash Push.sh --force                # skip detect, add all skills/ changes
#   bash Push.sh --skip-readme-check    # bypass README hard gate

set -euo pipefail

# === Configuration (HARDCODED) ===
SKILLS_REPO="$HOME/github/ljg-skills"
REPO_URL_EXPECTED="peng051410/ljg-skills"

# === Args ===
DRY_RUN=0
FORCE=0
SKIP_README_CHECK=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)            DRY_RUN=1 ;;
    --force)              FORCE=1 ;;
    --skip-readme-check)  SKIP_README_CHECK=1 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# dry-run downgrades the README gate to a warning so users still see drift but
# don't have to fix it before previewing.
if [ "$DRY_RUN" = "1" ]; then
  SKIP_README_CHECK=1
fi

# === Helpers ===

log()  { printf '\033[36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m+ %s\033[0m\n' "$*"; }
warn() { printf '\033[33m! %s\033[0m\n' "$*"; }
err()  { printf '\033[31mx %s\033[0m\n' "$*" >&2; }

# Verify canonical repo exists and points at the right fork.
verify_repo() {
  if [ ! -d "$SKILLS_REPO" ]; then
    err "$SKILLS_REPO does not exist."
    err "Canonical repo missing — clone manually: git clone git@github.com:peng051410/ljg-skills.git $SKILLS_REPO"
    exit 1
  fi
  local actual
  actual=$(cd "$SKILLS_REPO" && git remote get-url origin 2>/dev/null || echo "")
  if [[ "$actual" != *"$REPO_URL_EXPECTED"* ]]; then
    err "$SKILLS_REPO origin is '$actual', expected to contain '$REPO_URL_EXPECTED'."
    err "This protects against accidentally pushing to upstream lijigang/ljg-skills."
    exit 1
  fi
}

# List all skill directories (any naming pattern: ljg-*, tomyli-*, or none).
list_all_skills() {
  for d in "$SKILLS_REPO"/skills/*/; do
    [ -d "$d" ] || continue
    basename "$d"
  done
}

# Detect skills with uncommitted changes (modified, added, deleted, untracked).
# Echoes one skill name per line.
detect_changed_skills() {
  cd "$SKILLS_REPO"
  # Match files under skills/<name>/...; extract <name>.
  git status --porcelain skills/ | awk '{print $NF}' | awk -F/ '/^skills\//{print $2}' | sort -u
}

# Bump patch version in plugin.json + marketplace.json. Echoes new version.
bump_version() {
  local plugin=".claude-plugin/plugin.json"
  local marketplace=".claude-plugin/marketplace.json"
  local current major minor patch new
  current=$(grep -m1 '"version"' "$plugin" | sed 's/.*"\([0-9]*\.[0-9]*\.[0-9]*\)".*/\1/')
  major=$(echo "$current" | cut -d. -f1)
  minor=$(echo "$current" | cut -d. -f2)
  patch=$(echo "$current" | cut -d. -f3)
  new="$major.$minor.$((patch + 1))"
  sed -i '' "s/\"version\": \"$current\"/\"version\": \"$new\"/" "$plugin"
  sed -i '' "s/\"version\": \"$current\"/\"version\": \"$new\"/" "$marketplace"
  echo "$new"
}

# README consistency check. Hard gate by default.
check_readme() {
  local readme="$SKILLS_REPO/README.md"
  if [ ! -f "$readme" ]; then
    warn "README.md not found at $readme (skipping check)"
    return 0
  fi

  local repo_skills readme_skills missing
  repo_skills=$(list_all_skills | sort -u)
  # Match any skill-like token: word with dashes that resembles known prefixes
  # OR appears as a top-level skills/<name>/ path.
  # Strategy: extract all tokens that look like 'word' or 'word-word' and intersect.
  readme_skills=$(grep -oE '[a-z][a-z0-9-]*' "$readme" | sort -u)
  missing=$(comm -23 <(echo "$repo_skills") <(echo "$readme_skills"))

  if [ -z "$missing" ]; then
    ok "README mentions all skill directories"
    return 0
  fi

  warn "README is missing these skills:"
  echo "$missing" | sed 's/^/    - /'
  echo ""
  warn "Each push is a chance to refresh README. Ask yourself:"
  echo "    - 新增 skill 了吗？ → README 的清单 / 安装命令需要加一行"
  echo "    - 删了 skill 了吗？ → README 对应行要删"
  echo "    - skill 描述大改了吗？ → README 的简介可能要同步"
  echo ""
  if [ "$SKIP_README_CHECK" = "1" ]; then
    warn "--skip-readme-check passed (or --dry-run): ignoring above and continuing."
    return 0
  fi
  err "Aborting push. Update README first, or pass --skip-readme-check."
  exit 1
}

# === Main ===

verify_repo
cd "$SKILLS_REPO"

log "Repo: $SKILLS_REPO"
log "Origin: $(git remote get-url origin)"
log ""

log "Checking README consistency..."
check_readme
log ""

log "Detecting changes..."
if [ "$FORCE" = "1" ]; then
  CHANGED=$(list_all_skills)
  log "  --force: will commit all current skills/ state"
else
  CHANGED=$(detect_changed_skills || true)
fi

if [ -z "$CHANGED" ] && [ "$FORCE" = "0" ]; then
  log "Nothing to push."
  exit 0
fi

log "Changed skills:"
echo "$CHANGED" | sed 's/^/  - /'
log ""

if [ "$DRY_RUN" = "1" ]; then
  log "[dry-run] Would: git checkout master + pull --rebase + bump version + commit + push"
  exit 0
fi

# Ensure we're on master.
log "=== Branch: master ==="
git checkout master 2>&1 | head -1 || true
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "master" ]; then
  err "checkout master failed (still on $current_branch). Commit or stash uncommitted changes first."
  exit 1
fi

git pull --rebase --quiet || {
  warn "pull --rebase failed — please resolve manually (rebase --abort if needed) and re-run"
  exit 1
}

# Bump version BEFORE staging so plugin.json/marketplace.json get included.
new_ver=$(bump_version)

git add skills/ .claude-plugin/

if [ -z "$(git diff --cached --name-only)" ]; then
  log "No staged changes after add — likely already committed. Skipping commit."
else
  skill_list=$(echo "$CHANGED" | tr '\n' ' ' | sed 's/ $//')
  git commit -m "feat: sync skills [$skill_list] (v$new_ver)" --quiet
  ok "Committed v$new_ver"
fi

git push origin master --quiet
ok "master @ v$new_ver pushed"

log ""
log "═══ tomyli-push report ═══"
log "Updated skills:"
echo "$CHANGED" | sed 's/^/  - /'
log ""
log "master @ v$new_ver → pushed"
log "══════════════════════════"

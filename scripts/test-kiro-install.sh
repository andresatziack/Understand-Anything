#!/usr/bin/env bash
# Smoke test for `install.sh kiro` and `install.sh --uninstall kiro`.
#
# Isolates HOME via mktemp and snapshots the current working tree (committed
# files + untracked) into a temporary source repo, then points UA_REPO_URL at
# that snapshot via file://. This exercises the real installer code paths
# without touching the user's actual home directory or hitting GitHub, and it
# tests the in-progress branch state regardless of what's been committed.
# Asserts that the per-skill symlink lifecycle and the steering-file copy
# lifecycle both work end-to-end.
#
# Usage: bash scripts/test-kiro-install.sh
# Exits 0 on success, non-zero on the first failed assertion.

set -euo pipefail

# --- Locate repo root (one level up from this script) and confirm it has .git
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." &> /dev/null && pwd)"

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  printf 'error: %s is not a git checkout (no .git directory). Run from a clone.\n' "$REPO_ROOT" >&2
  exit 1
fi

if [[ ! -f "$REPO_ROOT/install.sh" ]]; then
  printf 'error: install.sh not found at %s\n' "$REPO_ROOT/install.sh" >&2
  exit 1
fi

# --- Set up isolated HOME and snapshot dir; clean both up on any exit
TEST_HOME="$(mktemp -d)"
SRC_REPO="$(mktemp -d)"
cleanup() {
  if [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]]; then
    rm -rf "$TEST_HOME"
  fi
  if [[ -n "${SRC_REPO:-}" && -d "$SRC_REPO" ]]; then
    rm -rf "$SRC_REPO"
  fi
}
trap cleanup EXIT INT TERM

# Snapshot the current working tree (including untracked files like the new
# .kiro-plugin/ and understand-anything-plugin/.kiro/ folders) into a fresh
# git repo so the test runs against the in-progress branch state, not just
# committed history. Skip heavy dirs we don't need.
if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude='/.git/' \
    --exclude='node_modules/' \
    --exclude='.pnpm-store/' \
    --exclude='dist/' \
    "$REPO_ROOT/" "$SRC_REPO/"
else
  cp -a "$REPO_ROOT/." "$SRC_REPO/"
  rm -rf "$SRC_REPO/.git" "$SRC_REPO/node_modules" "$SRC_REPO/.pnpm-store"
fi

# Initialize a clean git repo over the snapshot so install.sh's `git clone`
# step has something to clone from. The throwaway author values keep the
# commit deterministic without touching the user's git config.
git -C "$SRC_REPO" init -q -b main
git -C "$SRC_REPO" -c user.email=test@example.invalid -c user.name=test add -A
git -C "$SRC_REPO" -c user.email=test@example.invalid -c user.name=test commit -q -m snapshot

export HOME="$TEST_HOME"
export UA_DIR="$HOME/.understand-anything/repo"
export UA_REPO_URL="file://$SRC_REPO"

printf -- '--- kiro install round-trip smoke test ---\n'
printf '  HOME         = %s\n' "$HOME"
printf '  UA_DIR       = %s\n' "$UA_DIR"
printf '  UA_REPO_URL  = %s\n' "$UA_REPO_URL"
printf '\n'

fail() {
  printf '\n✗ %s\n' "$1" >&2
  exit 1
}

# --- Phase 1: install
printf '→ Running: bash install.sh kiro\n'
bash "$REPO_ROOT/install.sh" kiro || fail "install.sh kiro exited non-zero"

SKILL_LINK="$HOME/.kiro/skills/understand/SKILL.md"
STEERING_FILE="$HOME/.kiro/steering/understand-anything.md"

# Resolves through the per-skill symlink and confirms the target SKILL.md
# exists. -e follows the symlink, so this also catches dangling links.
if [[ ! -e "$SKILL_LINK" ]]; then
  fail "expected skill entry at $SKILL_LINK (per-skill symlink should resolve to a real SKILL.md)"
fi

if [[ ! -f "$STEERING_FILE" ]]; then
  fail "expected steering file at $STEERING_FILE"
fi

printf '\n  ✓ post-install: %s exists\n' "$SKILL_LINK"
printf '  ✓ post-install: %s exists\n' "$STEERING_FILE"

# --- Phase 2: uninstall
printf '\n→ Running: bash install.sh --uninstall kiro\n'
bash "$REPO_ROOT/install.sh" --uninstall kiro || fail "install.sh --uninstall kiro exited non-zero"

# After uninstall the per-skill directory should be gone (the parent
# ~/.kiro/skills/ may still exist but ~/.kiro/skills/understand should not).
# -L tests for symlink presence, -e tests for any kind of entry; we want
# neither.
if [[ -L "$HOME/.kiro/skills/understand" || -e "$HOME/.kiro/skills/understand" ]]; then
  fail "expected $HOME/.kiro/skills/understand to be removed by uninstall, but it still exists"
fi

if [[ -e "$STEERING_FILE" ]]; then
  fail "expected $STEERING_FILE to be removed by uninstall, but it still exists"
fi

printf '\n  ✓ post-uninstall: %s is gone\n' "$HOME/.kiro/skills/understand"
printf '  ✓ post-uninstall: %s is gone\n' "$STEERING_FILE"

printf '\n✓ kiro install round-trip OK\n'

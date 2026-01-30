#!/bin/bash
# Quick dashboard update helper
# Usage: ./update-dashboard.sh <command> [args]

DASHBOARD_DIR="/Users/cmpdbot/clawd/henry-dashboard"
TASKS_FILE="$DASHBOARD_DIR/data/tasks.json"
SW_FILE="$DASHBOARD_DIR/sw.js"

# Bump service worker version
bump_version() {
  current=$(grep "const VERSION" "$SW_FILE" | sed "s/.*'v\([0-9.]*\)'.*/\1/")
  major=$(echo $current | cut -d. -f1)
  minor=$(echo $current | cut -d. -f2)
  patch=$(echo $current | cut -d. -f3)
  new_patch=$((patch + 1))
  new_version="v$major.$minor.$new_patch"
  sed -i '' "s/const VERSION = 'v[0-9.]*'/const VERSION = '$new_version'/" "$SW_FILE"
  echo "Version bumped to $new_version"
}

# Push changes to GitHub
push_changes() {
  cd "$DASHBOARD_DIR"
  git add -A
  git commit -m "${1:-Dashboard update}"
  git push
  echo "Pushed to GitHub"
}

# Set task paused state
set_paused() {
  if [ "$1" = "true" ]; then
    sed -i '' 's/"paused": false/"paused": true/' "$TASKS_FILE"
    echo "Task paused"
  else
    sed -i '' 's/"paused": true/"paused": false/' "$TASKS_FILE"
    echo "Task resumed"
  fi
}

# Add completed item
add_completed() {
  title="$1"
  time=$(date +"%I:%M %p")
  # Use jq if available, otherwise manual
  if command -v jq &> /dev/null; then
    tmp=$(mktemp)
    jq ".completedToday = [{\"title\": \"$title\", \"time\": \"$time\"}] + .completedToday" "$TASKS_FILE" > "$tmp"
    mv "$tmp" "$TASKS_FILE"
  fi
  echo "Added: $title at $time"
}

# Update next task
set_next_task() {
  title="$1"
  desc="$2"
  time="$3"
  type="$4"
  if command -v jq &> /dev/null; then
    tmp=$(mktemp)
    jq ".nextTask = {\"title\": \"$title\", \"description\": \"$desc\", \"scheduledTime\": \"$time\", \"type\": \"$type\"}" "$TASKS_FILE" > "$tmp"
    mv "$tmp" "$TASKS_FILE"
  fi
  echo "Next task: $title"
}

# Update progress
update_progress() {
  progress="$1"
  sed -i '' "s/\"progress\": \"[^\"]*\"/\"progress\": \"$progress\"/" "$TASKS_FILE"
  echo "Progress updated: $progress"
}

# Update last updated timestamp
update_timestamp() {
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S+10:30")
  sed -i '' "s/\"lastUpdated\": \"[^\"]*\"/\"lastUpdated\": \"$timestamp\"/" "$TASKS_FILE"
}

# Main command router
case "$1" in
  pause)
    set_paused true
    update_timestamp
    bump_version
    push_changes "Paused current task"
    ;;
  resume)
    set_paused false
    update_timestamp
    bump_version
    push_changes "Resumed current task"
    ;;
  complete)
    add_completed "$2"
    update_timestamp
    bump_version
    push_changes "Completed: $2"
    ;;
  next)
    set_next_task "$2" "$3" "$4" "$5"
    update_timestamp
    bump_version
    push_changes "Next task: $2"
    ;;
  progress)
    update_progress "$2"
    update_timestamp
    bump_version
    push_changes "Progress: $2"
    ;;
  push)
    bump_version
    push_changes "$2"
    ;;
  *)
    echo "Usage: $0 {pause|resume|complete|next|progress|push} [args]"
    echo ""
    echo "Commands:"
    echo "  pause                    - Pause current task"
    echo "  resume                   - Resume current task"
    echo "  complete \"task name\"     - Add to completed today"
    echo "  next \"title\" \"desc\" \"time\" \"type\" - Set next task"
    echo "  progress \"X/Y complete\"  - Update progress"
    echo "  push \"commit message\"    - Just push changes"
    ;;
esac

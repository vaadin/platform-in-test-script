patchRouterLink() {
  return;
  find src -name "*.java" | xargs perl -pi -e 's/RouterLink\(null, /RouterLink("", /g'
  H=`git status --porcelain src`
  if [ -n "$H" ]; then
    log "patced RouterLink occurrences in files: $F"
  fi
}
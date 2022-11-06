#!/usr/bin/env bash

print_entry() {
    echo "$2$1"
}

print_tree() {
  local i=
  local tabs="$1"
  eval $CMD | while read i; do
    i=${i/.\/}
    ! $PRINT_HIDDEN && [[ $i == .* ]] && continue
    print_entry "$i" "$tabs"
    if [[ -d "$i" ]]; then
      cd "$i"
      print_tree "$tabs$TABS"
      cd ..
    fi
  done
}

tree_full() {
  local CMD="ls -A"
  print_tree
}

tree_short() {
  local CMD="find . -maxdepth 1 -type d | sort"
  print_tree
}

PRINT_HIDDEN=${PRINT_HIDDEN:-false}
TABS=${TABS:-"  "}

${1:-"tree_full"}


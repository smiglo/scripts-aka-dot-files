#/bin/bash
# vim: fdl=0

# Initial checks & set up # {{{
[[ -z $TICKET_PATH ]] && "Env[TICKET_PATH] not defined (tt-s)" >/dev/stderr && exit 1
[[ -z $TICKET_TOOL_PATH ]] && "Env[TICKET_TOOL_PATH] not defined (tt-s)" >/dev/stderr && exit 1
getPath() { # {{{
  local path_issue= ext= issue="$1" must_exisit="${2:-false}"
  for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    path_issue=$($ext --ticket-path $issue)
    if $must_exisit; then
      [[ -e "$path_issue/${issue}-data.txt" || -e "$path_issue/.${issue}-data.txt" ]] && break
    else
      [[ ! -z $path_issue ]] && break
    fi
  done # }}}
  if $must_exisit; then
    [[ ! -e "$path_issue/${issue}-data.txt" && ! -e "$path_issue/.${issue}-data.txt" ]] && path_issue="$TICKET_PATH/$issue"
  else
    [[ -z $path_issue ]] && path_issue="$TICKET_PATH/$issue"
  fi
  echo "$path_issue"
} # }}}
do_eval=true do_open=false
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --no-eval)  do_eval=false;;
  --open)     do_open=true;;
  --get-path) getPath "$2" "$3"; exit 0;;
  *)          break;;
  esac
  shift
done # }}}
export issue="$1"
shift
if [[ -z $issue ]] && $do_open; then # {{{
  [[ ! -z $TICKET_TMUX_SESSION ]] && tmux-startup.sh --do-env -- "$TICKET_TMUX_SESSION"
  for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    $ext --open
  done # }}}
  exit 0
fi # }}}
# }}}
# Path to issue # {{{
export path_issue="$(getPath "$issue")"
# }}}
fname="$path_issue/${issue}-data.txt"
fnameH="$path_issue/.${issue}-data.txt"
if [[ ! -e "$fname" && ! -e "$fnameH" ]]; then # {{{
  cnt=10
  while ! command mkdir -p "$path_issue"; do
    sleep 0.5
    [[ -e "$fname" ]] && break
    cnt="$(($cnt-1))"
    [[ $cnt == 0 ]] && break
  done
  unset cnt
fi # }}}
if [[ ! -e "$fname" && ! -e "$fnameH" ]]; then # {{{
  touch "$fname"
  for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    $ext --setup "$@"
  done # }}}
  # Template of data file {{{
  # Main # {{{
  cat >"$fname" <<-"EOF"
		# vim: ft=sh fdm=marker fdl=0
		# j-info: -ALWAYS-INCLUDE, -DONE
		
		# env -# {{{
		# tmux set-buffer -b "${issue}-desc"   ''
		@@ ENV @@
		# }}}
		# -info # {{{
		# For separators use: ---, ===; for sections: ## @, or ## @ {{{ + ## @ }}}
		@@ ## @ Description @@
		@@ DESCRIPTION @@
		@@ INFO @@
		# }}}
	EOF
  # }}}
  for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    $ext --template "$fname" "$@"
  done # }}}
  # Additional # {{{
  tmux_template_added=false
  for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-setup-ext.sh); do
    $ext --template-tmux "$fname" "$@" && tmux_template_added=true && break
  done
  if ! $tmux_template_added; then # {{{
    cat >>"$fname" <<-"EOF"
			# tmux -# {{{
			# tmux-splits -# {{{
			pl_abs="$(command cd $path_issue; pwd)"
			tmux \
			  new-window   -a    -c $pl_abs          \; \
			  split-window -t .1 -c $pl_abs -v -p30
			# }}}
			# tmux-cmds -# {{{
			tmux \
			  select-pane  -t $w.1
			# }}}
			# }}}
			
		EOF
  fi # }}}
  # }}}
  # }}}
  for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    $ext --setup-post "$fname" "$@"
  done # }}}
  templates="${TICKET_TEMPLATES:-$TICKET_PATH/.templates}"
  if [[ -d "$templates" ]]; then
    for i in $templates/*.tmpl; do
      [[ ! -e "$i" ]] && continue
      t="${i##*/}" && t="${t%%.*}"
      sed -i -e "/^@@ ${t^^} @@$/ { r $i
        d; }" "$fname"
      i="${i/.tmpl/.hdr}"
      [[ ! -e "$i" ]] && continue
      sed -i -e "/^# ${t,,} .*/ { r $i
        d; }" "$fname"
    done
  fi
  unset templates i t
  sed -i -e '/^@@ .* @@$/ d' "$fname"
  if git -C $TICKET_PATH rev-parse 2>/dev/null; then # {{{
    command cd $path_issue
    git add -f "${fname#${path_issue}/}"
    git add .
    git commit -m"[i] $issue" --no-verify
    command cd - >/dev/null 2>&1
  fi # }}}
fi # }}}
if $do_open; then # {{{
  [[ ! -z $TICKET_TMUX_SESSION ]] && tmux-startup.sh --do-env -- "$TICKET_TMUX_SESSION" "$issue"
  for ext in $(command find -L $BASH_PATH/profiles/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    $ext --open "$issue" "$@"
  done # }}}
  if [[ ! -z $TICKET_TMUX_SESSION ]] && ! tmux list-windows -t $TICKET_TMUX_SESSION -F '#W' | command grep -qi "$issue"; then
    $TICKET_TOOL_PATH/ticket-tool.sh --issue $issue tmux 'INIT'
  fi
fi # }}}
$do_eval && eval $($TICKET_TOOL_PATH/ticket-tool.sh --issue "$issue" 'env' --silent)
unset path_issue issue do_eval do_open fname fnameH


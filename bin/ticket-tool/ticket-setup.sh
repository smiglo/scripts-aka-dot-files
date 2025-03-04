#!/usr/bin/env bash
# vim: fdl=0

# Initial checks & set up # {{{
[[ -z $TICKET_PATH ]] && echo "Env[TICKET_PATH] not defined (tt-s)" >/dev/stderr && exit 1
[[ -z $TICKET_TOOL_PATH ]] && echo "Env[TICKET_TOOL_PATH] not defined (tt-s)" >/dev/stderr && exit 1
getPath() { # {{{
  local issue="$1" must_exisit="${2:-false}" ext=
  local path_issue="$TICKET_PATH/$issue"
  [[ -e "$path_issue/${issue}-data.txt" || -e "$path_issue/.${issue}-data.txt" ]] && echo "$path_issue" && return 0
  for ext in $(find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    path_issue=$($ext --ticket-path $issue)
    if $must_exisit; then
      [[ -e "$path_issue/${issue}-data.txt" || -e "$path_issue/.${issue}-data.txt" ]] && break
    else
      [[ ! -z $path_issue ]] && break
    fi
  done # }}}
  if $must_exisit; then
    [[ ! -e "$path_issue/${issue}-data.txt" && ! -e "$path_issue/.${issue}-data.txt" ]] && return 1
  else
    [[ -z $path_issue ]] && path_issue="$TICKET_PATH/$issue"
  fi
  echo "$path_issue"
} # }}}
do_eval=true do_open=false title=false recreate=false do_layout=false
always=${TICKET_SETUP_ALWAYS:-false} done=${TICKET_SETUP_DONE:-false}
hidden=${TICKET_SETUP_HIDDEN:-false} minimal=${TICKET_SETUP_MINIMAL:-false}
while [[ ! -z $1 ]]; do # {{{
  case $1 in
  --no-eval)   do_eval=false;;
  --open)      do_open=true;;
  --layout)    do_layout=true; do_eval=false;;
  --get-path)  getPath "$2" "$3"; exit $?;;
  --always)    always=true;;
  --no-always) always=false;;
  --done)      done=true;;
  --no-done)   done=false;;
  --hide)      hidden=true;;
  --no-hide)   hidden=false;;
  --min)       minimal=true;;
  --no-min)    minimal=false;;
  --recreate)  recreate=true;;
  --title)     title=true;;
  -*) # -mdh # {{{
    v="${1:1}"
    echo "$v" | grep -q "^[adhmt]\+$" || break
    while [[ ! -z $v ]]; do
      case ${v:0:1} in
      a) always=true;; d) done=true;; h) hidden=true;; m) minimal=true;; t) title=true;;
      esac
      v="${v:1}"
    done;; # }}}
  *) break;;
  esac
  shift
done # }}}
export issue="$1"
$title && title="$issue" || title=
issue="${issue,,}"
shift
if [[ -z $issue ]]; then # {{{
  if $do_open; then # {{{
    [[ ! -z $TICKET_TMUX_SESSION ]] && tmux-startup.sh --do-env -- "$TICKET_TMUX_SESSION"
    for ext in $(find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
      $ext --open
    done # }}}
  fi # }}}
  exit 0
fi # }}}
# }}}
# Path to issue # {{{
export path_issue="$(getPath "$issue")"
if [[ -z $path_issue ]]; then
  [[ $0 == ${BASH_SOURCE[0]} ]] && exit 0 || return 0
fi
# }}}
fname="$path_issue/${issue}-data.txt"
fnameH="$path_issue/.${issue}-data.txt"
$recreate && { mv $fname ${fname}.old; mv $fnameH ${fnameH}.old; } >/dev/null 2>&1
if [[ ! -e "$fname" && ! -e "$fnameH" ]]; then # {{{
  cnt=10
  while ! mkdir -p "$path_issue"; do
    sleep 0.5
    [[ -e "$fname" ]] && break
    cnt="$(($cnt-1))"
    [[ $cnt == 0 ]] && break
  done
  unset cnt
fi # }}}
if [[ ! -e "$fname" && ! -e "$fnameH" ]]; then # {{{
  $hidden && fname="$fnameH"
  touch "$fname"
  # Pre-setup # {{{
  for ext in $(find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do
    $ext --setup "$@"
  done
  # }}}
  # Template of data file # {{{
  # Header # {{{
  cat >>"$fname" <<-"EOF"
		# ## Header # {{{
		# vim: ft=sh fdm=marker fdl=0
		# j-info: CONF: conf=([use-new-args]=true)
		# j-info: -ALWAYS-INCLUDE, -DONE
		# j-info: -LAYOUT:
		# j-info: -ENV:
		@@ j-info: @@
		# ## }}}
	EOF
  $always && sed -i 's/-ALWAYS-INCLUDE/ALWAYS-INCLUDE/' "$fname"
  $done && sed -i 's/-DONE/DONE/' "$fname"
  [[ ! -z $title ]] && sed -i "s/@@ j-info: @@/# j-info: TITLE: $title\n\0/" "$fname"
  # }}}
  if ! $minimal; then # {{{
    # Main # {{{
    cat >>"$fname" <<-"EOF"
			
			# env -# {{{
			# tmux set-buffer -b "${issue}-desc"   ''
			# echo "export var=val"
			@@ ENV @@
			# }}}
			# -setup -# {{{
			[[ -z $scmd ]] && scmd=$1 && shift
			echorm --name tt:setup +
			case $scmd in
			# alias)   commands;; # @@: compl
			@travelsal) # {{{
			  case $2 in
			  # -INIT-) echo "alias";;
			  # alias)  echo "next-alias | next-alias2";;
			  esac ;; # }}}
			\?) # {{{
			  case $2 in
			  # alias) echo "Description";;
			  esac;; # }}}
			esac
			# }}}
			# -info # {{{
			# For separators use: ---, ===; for sections: ## @, or [## @ ... # {{.] + [## @ }}. where 'dot' is the third bracket]
			@@ ## @ Description @@
			@@ DESCRIPTION @@
			@@ INFO @@
			# }}}
		EOF
    for ext in $(find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
      $ext --template-main "$fname" "$@"
    done # }}}
    # }}}
    # Others # {{{
    cat >>"$fname" <<-"EOF"
			# -others-tbd # {{{
			# -browser -# {{{
			echorm --name tt:browser
			@@ BROWSER @@
			# }}}
		EOF
    for ext in $(find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
      $ext --template-oth "$fname" "$@"
    done # }}}
    # Tmux # {{{
    cat >>"$fname" <<-"EOF"
			# tmux -# {{{
		EOF
    tmux_template_added=false
    for ext in $(find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
      $ext --template-tmux "$fname" "$@" && tmux_template_added=true && break
    done # }}}
    if ! $tmux_template_added; then # {{{
      cat >>"$fname" <<-"EOF"
				# -tmux-init -# {{{
				echorm --name tt:tmux
				tmux split-window -t $w.2 -d -c $pl_abs -h -p50
				# }}}
				# -tmux-splits -# {{{
				echorm --name tt:tmux
				tmux \
				  new-window   -a -n $title -c $pl_abs  \; \
				  set-option   -w @locked_title 1          \; \
				  split-window -t .1 -d -c $pl_abs -v -p30
				# }}}
				# -tmux-cmds -# {{{
				echorm --name tt:tmux
				# }}}
			EOF
    fi # }}}
    cat >>"$fname" <<-"EOF"
			# }}}
		EOF
    # }}}
    cat >>"$fname" <<-"EOF"
			# }}}
			
		EOF
    # }}}
  fi # }}}
  # }}}
  # Post-setup # {{{
  for ext in $(find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    $ext --setup-post "$fname" "$@"
  done # }}}
  # }}}
  # Section templates (@@ - @@) # {{{
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
  # }}}
  # Auto-commit # {{{
  if git -C $TICKET_PATH rev-parse 2>/dev/null; then
    cd $path_issue
    git add -f "${fname#${path_issue}/}"
    git add .
    git commit -m"[$issue]" --no-verify
    echo
    cd - >/dev/null 2>&1
  fi # }}}
fi # }}}
if $do_open; then # {{{
  [[ ! -z $TICKET_TMUX_SESSION ]] && tmux-startup.sh --do-env -- "$TICKET_TMUX_SESSION" "$issue"
  for ext in $(find -L $PROFILES_PATH/ -path \*ticket-tool/ticket-setup-ext.sh); do # {{{
    $ext --open "$issue"
  done # }}}
  if [[ ! -z $TICKET_TMUX_SESSION ]] && ! tmux list-windows -t $TICKET_TMUX_SESSION -F '#W' | grep -qi "$issue"; then
    $TICKET_TOOL_PATH/ticket-tool.sh --issue $issue tmux 'INIT'
  fi
  if $do_layout; then # {{{
    $TICKET_TOOL_PATH/ticket-tool.sh --issue $issue layout -q restore
  fi # }}}
fi # }}}
if $do_eval; then # {{{
  if [[ -n $TMUX ]]; then
    if [[ -z $TICKET_CONF_ENV_LAST || $((${EPOCHSECONDS:-$(epochSeconds)} - TICKET_CONF_ENV_LAST)) -gt 10 ]] && [[ $(tmux display-message -t $TMUX_PANE -pF '#W') == "${issue^^}"* ]]; then
      eval "$($TICKET_TOOL_PATH/ticket-tool.sh --issue "$issue" 'env' --silent)"
      if [[ ! -z $TICKET_TOOL_POST_ENV ]]; then # {{{
        while read post_env; do
          eval $post_env
        done <<<"$(echo -e "$TICKET_TOOL_POST_ENV")"
      fi # }}}
    else
      $TICKET_TOOL_PATH/ticket-tool.sh --issue "$issue" 'env' --silent >/dev/null
    fi
    TICKET_CONF_ENV_LAST="${EPOCHSECONDS:-$(epochSeconds)}"
  fi
fi # }}}
unset path_issue issue do_eval do_open do_layout fname fnameH post_env getPath always


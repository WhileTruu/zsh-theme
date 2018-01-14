CURRENT_BG='NONE'

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

prompt_element() {
  [[ -n $2 ]] && echo -n "%{$fg[$1]%}$2%{$reset_color%}"
}

bold_prompt_element() {
  if [[ -n $2 ]]; then
    echo -n "$FX[bold]"
    prompt_element $1 $2
    echo -n "$FX[no-bold]"
  fi
}

# End the prompt, closing any open segments
prompt_end() {
  bold_prompt_element default " »"
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ $RETVAL -ne 0 ]]; then
    bold_prompt_element red "λ"
  elif [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    bold_prompt_element yellow "λ"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  (( $+commands[git] )) || return
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0'         # 
  }
  local ref dirty mode repo_path color
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      color=yellow
    else
      color=green
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:*' unstagedstr '●'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    bold_prompt_element default " git:"
    prompt_element $color "${ref/refs\/heads\//}${vcs_info_msg_0_%% }${mode}"
  fi
}

prompt_bzr() {
    (( $+commands[bzr] )) || return
    if (bzr status >/dev/null 2>&1); then
        status_mod=`bzr status | head -n1 | grep "modified" | wc -m`
        status_all=`bzr status | head -n1 | wc -m`
        revision=`bzr log | head -n2 | tail -n1 | sed 's/^revno: //'`
        if [[ $status_mod -gt 0 ]] ; then
            prompt_segment yellow black
            echo -n "bzr@"$revision "✚ "
        else
            if [[ $status_all -gt 0 ]] ; then
                prompt_segment yellow black
                echo -n "bzr@"$revision

            else
                prompt_segment green black
                echo -n "bzr@"$revision
            fi
        fi
    fi
}

prompt_hg() {
  (( $+commands[hg] )) || return
  local rev hg_st color
  if $(hg id >/dev/null 2>&1); then
    hg_st=""
    revision=$(hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
    branch=$(hg id -b 2>/dev/null)
    local hg_st_output=$(hg st)
    if `echo $hg_st_output | grep -q "^\?"`; then
      # has files that are not added
      color=red
      hg_st+='?'
    fi
    if `echo $hg_st_output | grep -q "^[M]"`; then
      # has modified files
      color=yellow
      hg_st+='M'
    fi
    if `echo $hg_st_output | grep -q "^[A]"`; then
      # has added files
      color=yellow
      hg_st+='A'
    else
      color=green
    fi
    echo -n " "
    bold_prompt_element default "hg"
    echo -n ":"
    prompt_element $color $revision
    prompt_element default ":"
    prompt_element $color $branch 
    [[ -n $hg_st ]] && echo -n " $hg_st"
  fi
}

# Dir: current working directory
prompt_dir() {
  bold_prompt_element cyan ' %2~'
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && echo -n " $symbols"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  # prompt_virtualenv
  prompt_context
  prompt_dir
  prompt_git
  # prompt_bzr
  prompt_hg
  prompt_status
  prompt_end
}

PROMPT='%{%f%b%k%}$(build_prompt) '
BASE_DIR=$(dirname $0)
CONFIG="$BASE_DIR/config.json"
ORIG_CD=__orig_cd

CONFIG_FILES=__files__
CONFIG_NAME=__name__
LOCAL_CONFIG=.pludo

alias c.="code ."
alias c="code -g"

alias l="lsd -la"
alias lt="lsd --tree"

alias activate=". .venv/bin/activate"

alias sido=sudo

__pludo_get_directory_type() {
  local res=""
  local found=0

  for type in $(jq 'keys[]' -r <"$CONFIG"); do
    local project_config=$(__pludo_get_config_for_type $type)

    for file in $(jq ".${CONFIG_FILES}[]" -r <<< "$project_config"); do
      if [[ -f "./$file" ]]; then
        res=$type
        found=$(($found + 1))
      fi
    done
  done

  if [[ $found = 1 ]]; then
    echo $res
  fi
}

__pludo_get_config_for_type() {
  jq '."'$1'"' <"$CONFIG"
}

__pludo_get_directory_config() {
  if [ -f $LOCAL_CONFIG ]; then
    cat $LOCAL_CONFIG
    return
  fi

  __pludo_get_config_for_type $(__pludo_get_directory_type)
}

__pludo_iter_cmds() {
  for cmd in $(jq 'keys[]' -r <<<"$1"); do
    if [[ ! $cmd == __* ]]; then
      echo $cmd "$(jq --raw-output '."'$cmd'"' <<<"$1")"
    fi
  done
}

__pludo_set_orig_cd() {
  local orig_type=`whence -w cd | rev | cut -f1 -d' ' | rev`

  if [[ "$orig_type" == "builtin" ]]; then
    $ORIG_CD() { builtin cd "${@}"; }
  else 
    eval "$(
      echo "$ORIG_CD() {";
      declare -f cd | tail -n +2
    )"
  fi
}

__pludo_load() {
  local type=$(__pludo_get_directory_type)

  if [[ $type == "" ]]; then
    return 1
  fi

  local project_config=$(__pludo_get_directory_config)

  __pludo_iter_cmds $project_config | while read -r name cmd; do alias "$name=$cmd"; done
}

__pludo_unload() {
  local type=$(__pludo_get_directory_type)

  if [[ $type == "" ]]; then
    return 1
  fi

  local project_config=$(__pludo_get_directory_config)

  __pludo_iter_cmds $project_config | while read -r name _; do unalias "$name" &> /dev/null; done
}

__pludo_status() {
  local type=$(__pludo_get_directory_type)

  if [[ $type == "" ]]; then
    echo "Pludo status: inactive"
    return
  fi

  local project_config=$(__pludo_get_directory_config)
  local project_name="$(jq -r ".$CONFIG_NAME" <<<"$project_config")"
  if [[ "$project_name" == "null" ]]; then
    export project_name="custom"
  fi

  echo "Pludo status: active"
  echo "- Project type: $project_name $(if [ -f $LOCAL_CONFIG ]; then echo '(local)'; fi)"
  echo "- Loaded aliases:"

  __pludo_iter_cmds $project_config | while read -r name cmd; do echo "  * $name -> $cmd"; done
}

pludo() {
    if [ "$1" = "status" ]; then
      __pludo_status
    elif [ "$1" = "load" ]; then
      __pludo_load
    elif [ "$1" = "unload" ]; then
      __pludo_unload
    else
      echo "Invalid command usage"
      echo "Syntax: pludo <cmd>"
      echo "  cmd :"
      echo "  - status"
      echo "  - load"
      echo "  - unload"
    fi
}

__pludo_set_orig_cd
__pludo_load

cd () {
  __pludo_unload
  $ORIG_CD "${@}"
  __pludo_load
}

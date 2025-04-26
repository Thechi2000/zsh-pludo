BASE_DIR=$(dirname $0)
CONFIG="$BASE_DIR/config.json"
ORIG_CD=__orig_cd

alias c.="code ."
alias c="code -g"

alias l="lsd -la"
alias lt="lsd --tree"

alias activate=". .venv/bin/activate"

alias sido=sudo

__get_project_type() {
  local res=""
  local found=0

  for type in $(jq 'keys[]' -r <"$CONFIG"); do
    if [[ -f "./$type" ]]; then
      res=$type
      found=$(($found + 1))
    fi
  done

  if [[ $found = 1 ]]; then
    echo $res
  fi
}

__set_orig_cd() {
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
  local type=$(__get_project_type)

  if [[ $type == "" ]]; then
    return 1
  fi

  local project_config=$(jq '."'$type'"' <"$CONFIG")

  export PLUDO_PROJECT_TYPE="$type"

  for cmd in $(jq 'keys[]' -r <<<"$project_config"); do
    alias "$cmd=$(jq --raw-output '."'$cmd'"' <<<"$project_config")"
  done
}

__pludo_unload() {
  local type=$(__get_project_type)

  if [[ $type == "" ]]; then
    return 1
  fi

  unset PLUDO_PROJECT_TYPE

  local project_config=$(jq '."'$type'"' <"$CONFIG")

  for cmd in $(jq 'keys[]' -r <<<"$project_config"); do
    unalias "$cmd" &> /dev/null
  done
}

__pludo_status() {
  if [ "$PLUDO_PROJECT_TYPE" != "" ]; then

    local project_config=$(jq '."'$PLUDO_PROJECT_TYPE'"' <"$CONFIG")
    local project_name="$(jq -r '.__name' <<<"$project_config")"
    if [[ "$project_name" == "null" ]]; then
      export project_name="custom"
    fi

    echo "Pludo status: active"
    echo "- Project type: $project_name"
  else
    echo "Pludo status: inactive"
  fi
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

__set_orig_cd
__pludo_load

cd () {
  __pludo_unload
  __orig_cd "${@}"
  __pludo_load
}

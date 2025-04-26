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

Reset='\e[0m'
Bright='\e[1m'
Dim='\e[2m'
Underscore='\e[4m'
Blink='\e[5m'
Reverse='\e[7m'
Hidden='\e[8m'

FgBlack='\e[30m'
FgRed='\e[31m'
FgGreen='\e[32m'
FgYellow='\e[33m'
FgBlue='\e[34m'
FgMagenta='\e[35m'
FgCyan='\e[36m'
FgWhite='\e[37m'

BgBlack='\e[40m'
BgRed='\e[41m'
BgGreen='\e[42m'
BgYellow='\e[43m'
BgBlue='\e[44m'
BgMagenta='\e[45m'
BgCyan='\e[46m'
BgWhite='\e[47m'

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
  for name in $(jq 'keys[]' -r <<<"$1"); do
    if [[ ! $name == __* ]]; then
      echo $name
    fi
  done
}

__pludo_cmd() {
  local value="$(jq '."'$2'"' <<<"$1")"
  if [ "$(jq -r '. | type' <<< "$value")" = "string" ]; then
    echo "$(jq -r . <<< "$value")"
  else
    echo "$(jq -r .cmd <<< "$value")"
  fi
}
__pludo_dir() {
  local value="$(jq '."'$2'"' <<<"$1")"
  if [ "$(jq -r '. | type' <<< "$value")" = "string" ]; then
    echo /
  else
    echo "$(jq -r .dir <<< "$value")"
  fi
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

  for name in $(__pludo_iter_cmds "$project_config"); do
    alias "$name=$(__pludo_cmd $project_config $name)"
  done
}

__pludo_unload() {
  local type=$(__pludo_get_directory_type)

  if [[ $type == "" ]]; then
    return 1
  fi

  local project_config=$(__pludo_get_directory_config)

  for name in $(__pludo_iter_cmds "$project_config"); do
    unalias "$name"
  done
}

__pludo_status() {
  local type=$(__pludo_get_directory_type)

  if [[ $type == "" ]]; then
    echo "${Bright}Pludo status: ${FgRed}inactive${Reset}"
    return
  fi

  local project_config=$(__pludo_get_directory_config)
  local project_name="$(jq -r ".$CONFIG_NAME" <<<"$project_config")"
  if [[ "$project_name" == "null" ]]; then
    export project_name="custom"
  fi

  echo "${Bright}Pludo status: ${FgGreen}active${Reset}"
  echo "- Project type: ${Bright}$project_name $(if [ -f $LOCAL_CONFIG ]; then echo '(local)'; fi)${Reset}"
  echo "- Loaded aliases:"

  for name in $(__pludo_iter_cmds "$project_config"); do
    local cmd="$(__pludo_cmd $project_config $name)"
    echo "  * ${Bright}${FgBlue}$name${Reset} -> $cmd"

    local dir="$(__pludo_dir $project_config $name)"
    if [ "$dir" != "/" ]; then
      echo "    from directory: $dir"
    fi
  done
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

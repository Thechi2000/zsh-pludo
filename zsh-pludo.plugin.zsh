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

PLUDO_CONFIG_DIR="$HOME/.config/pludo"

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
  local project_config=$(__pludo_get_directory_config)
  if [[ "$project_config" == "" ]]; then
    return 1
  fi

  for name in $(__pludo_iter_cmds "$project_config"); do
    local cmd=$(__pludo_cmd $project_config $name)
    local dir=$(__pludo_dir $project_config $name)

    eval "$name () (
      $(if [ "$dir" != "/" ]; then
        echo "$ORIG_CD $PWD/$dir || return 1"
      fi)
      $cmd \${@}
    )"
  done
}

__pludo_unload() {
  local project_config=$(__pludo_get_directory_config)
  if [[ "$project_config" == "" ]]; then
    return 1
  fi

  for name in $(__pludo_iter_cmds "$project_config"); do
    unset -f "$name"
  done
}

__pludo_status() {
  local project_config=$(__pludo_get_directory_config)
  if [[ "$project_config" == "" ]]; then
    return 1
  fi

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

__pludo_setup_config() (
  if [ ! -d "$PLUDO_CONFIG_DIR" ]; then
    mkdir -p "$PLUDO_CONFIG_DIR"
    cd "$PLUDO_CONFIG_DIR"
    
    git init .
    git commit --allow-empty -m "initial commit"
    git remote add origin "$PLUDO_CONFIG_REMOTE"

    git push --set-upstream origin main
  fi
)

__pludo_link() {
  __pludo_setup_config

  local config="$1"
  local config_path="$PLUDO_CONFIG_DIR/$config"

  if [ ! -f "$config_path" ]; then
    echo "${FgRed}Config \"$config\" does not exist !${Reset}"
    return 1
  fi

  ln -sf "$config_path" "$LOCAL_CONFIG"
}

__pludo_create() {
  __pludo_setup_config

  local config="$1"
  local config_path="$PLUDO_CONFIG_DIR/$config"

  if [ -f "$config_path" ]; then
    echo "${FgRed}Config \"$config\" already exists !${Reset}"
    return 1
  fi

  echo "Creating config ${Bright}\"$config\"${Reset} at $config_path"
  touch "$config_path"
  ln -sf "$config_path" "$LOCAL_CONFIG"
}

__pludo_delete() {
  __pludo_setup_config

  local config="$1"
  local config_path="$PLUDO_CONFIG_DIR/$config"

  if [ ! -f "$config_path" ]; then
    echo "${FgRed}Config \"$config\" does not exists !${Reset}"
    return 1
  fi

  echo "Deleting config ${Bright}\"$config\"${Reset}"
  rm "$config_path"

  if [ "$(readlink "$LOCAL_CONFIG")" = "$config_path" ]; then
    echo "Unlinking local config"
    rm "$LOCAL_CONFIG"
  fi
}

__pludo_save() (
  __pludo_setup_config

  local config="$1"

  if [ -z "$config" ]; then
    if [ ! -L "$LOCAL_CONFIG" ]; then
      echo "${Red}No config found !${Reset}"
      return 1
    fi

    config="$(basename "$(readlink "$LOCAL_CONFIG")")"
  fi

  cd "$PLUDO_CONFIG_DIR"
  
  git add "$config"
  git commit -m "updating $config"
  git push
)

__pludo_sync() (
  __pludo_setup_config
  cd "$PLUDO_CONFIG_DIR"

  git pull
)

pludo() {
    if [ "$1" = "status" ]; then
      __pludo_status
    elif [ "$1" = "load" ]; then
      __pludo_load
    elif [ "$1" = "unload" ]; then
      __pludo_unload
    elif [ "$1" = "link" ]; then
      __pludo_link $2
    elif [ "$1" = "create" ]; then
      __pludo_create $2
    elif [ "$1" = "delete" ]; then
      __pludo_delete $2
    elif [ "$1" = "save" ]; then
      __pludo_save $2
    elif [ "$1" = "sync" ]; then
      __pludo_sync $2
    else
      echo "Invalid command usage"
      echo "Syntax: pludo <cmd>"
      echo "  cmd :"
      echo "  - status"
      echo "  - load"
      echo "  - unload"
      echo "  - link <config>"
      echo "  - create <config>"
      echo "  - delete <config>"
      echo "  - save <config>"
    fi

    return $?
}

__pludo_set_orig_cd
__pludo_load

cd () {
  __pludo_unload
  $ORIG_CD "${@}"
  __pludo_load
}

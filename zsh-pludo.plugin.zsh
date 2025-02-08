BASE_DIR=$(dirname $0)
CONFIG="$BASE_DIR/config.json"

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

  if [[ $found = 0 ]]; then
    echo No project found
    return 1
  elif [[ $found = 1 ]]; then
    echo $res
    return 0
  else
    echo Multiple projects found
    return 2
  fi
}

load() {
  local type=$(__get_project_type)
  if [[ "$?" != 0 ]]; then
    return 1
  fi

  local project_config=$(jq '."'$type'"' <"$CONFIG")

  for cmd in $(jq 'keys[]' -r <<<"$project_config"); do
    alias "$cmd=$(jq --raw-output '."'$cmd'"' <<<"$project_config")"
  done
}

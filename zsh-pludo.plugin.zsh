BASE_DIR=$(dirname $0)

alias c.="code ."
alias c="code -g"

alias l="lsd -la"
alias lt="lsd --tree"

alias activate=". .venv/bin/activate"

alias sido=sudo

alias carbo="cargo build"
alias carro="cargo run"
alias carco="cargo check"


__get_project_type() {
  local res=""
  local found=0

  for type in $(jq 'keys[]' -r < "$BASE_DIR/config.json"); do 
    if [[ -f "./$type" ]]; then
      res=$type
      found=$(($found+1))
    fi
  done
  
  if [[ $found = 0 ]]; then 
    echo No project found
  elif [[ $found = 1 ]]; then
    echo $res
  else
    echo Multiple projects found
  fi
}

load() {

}

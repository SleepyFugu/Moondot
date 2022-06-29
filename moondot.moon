moondot_version = 'dev-1.0'

moon = require"moonscript.base"
path = require"pl.path"
parse_file = "#{os.getenv 'HOME'}/.moondot"

require"moondot.obj"

import sandbox, sandbox_export from require"moondot.env"
import emit, run_with_margin from require"moondot.output"
import for_os, coalesce, trim from require"moondot.utils"
import set, var, Config from require"moondot.obj.config"
import Repo from require"moondot.obj.repo"
import File, Template from require"moondot.obj.file"

flags_allowed = {
  file: "f"
  help: "h"
  usage: "u"
  version: "V"
}

flags_w_values = {
  'setvar'
  'file'
}

flags, params = require"pl.app".parse_args arg, flags_w_values, flags_allowed
if flags
  indent = '      '

  if flags.help
    print trim indent, [[
      Moondot
        User configuration file manager written in Moonscript`

      Usage
        moondot [options <values>] VAR=VAL VAR2=VAL2 ...

      Flags
        -h --help        This help text
        -f --file        File to parse (default: ~/.moondot)
        -V --version     Version string
    ]]
    os.exit 0

  if flags.file
    parse_file = flags.file

  if flags.version
    print moondot_version
    os.exit 0

  for p in *params
    key, val = p\match "^([a-zA-Z0-9_-]+)=([a-zA-Z0-9_-]+)$"
    if key and val
      unless set key, val
        Config key, val, (v) -> v

sandbox_export
  block: (name, fn) ->
    emit "Setting up #{name} ..."
    run_with_margin fn
  macos: (fn) ->
    for_os 'macos', fn
  linux: (fn) ->
    for_os 'linux', fn
  bsd: (fn) ->
    for_os 'bsd', fn
  windows: (fn) ->
    for_os 'bsd', fn
  :coalesce
  :tostring
  :string
  :ipairs
  :pairs
  :table

unless path.isfile parse_file
  print"Please supply a .moondot file located at: #{parse_file}"
  os.exit 1

if conf = moon.loadfile parse_file
  sandbox conf
else
  print"Please supply a valid .moondot file located at #{parse_file}"
  os.exit 1

print!

need_update = (o) ->
  emit "#{o}: %{yellow}Needs update"

emit_state = (bool) ->
  switch bool
    when true
      emit "State: %{green}Good"
    when false
      emit "State: %{red}Failed"

emit "Beginning sync run ..."
run_with_margin ->
  emit "Using cache: #{var.cache_dir}"
  if Repo.count! > 0
    emit "Enforcing repository state ..."
    run_with_margin -> Repo.each (r) ->
      emit "#{r}: Pulling remote"
      run_with_margin ->
        r\enforce!
        emit_state r.state

  if File.count! > 0
    emit "Enforcing file state ..."
    run_with_margin -> File.each (f) ->
      if not f\check!
        need_update f
        run_with_margin -> f\enforce!
      else
        emit "#{f}: %{green}Good"
        return
      run_with_margin -> emit_state f.state

  if Template.count! > 0
    emit "Enforcing template state ..."
    run_with_margin -> Template.each (f) ->
      if not f\check!
        need_update f
        run_with_margin -> f\enforce!
      else
        emit "#{f}: %{green}Good"
        return

      run_with_margin -> emit_state f.state

#!/bin/sh

if ! lua -v >/dev/null 2>&1; then
    echo "lua not installed.  try 'brew install lua' on mac os x or 'sudo apt-get install lua5.1' on ubuntu linux"
    exit
fi

# If $LUALIB is not set externally, set it to a default that works on a server install
${LUALIB:="/opt/opscode/embedded/lualib"}
echo $LUALIB

if [ ! -f lpeg.so ]; then
  ln -s $LUALIB/lpeg.so
fi

if [ ! -f cjson.so ]; then
  ln -s $LUALIB/cjson.so
fi

lua -e 'if pcall(require,"lpeg") then os.exit(0) else os.exit(1) end'
if [ $? -ne 0 ]; then
  echo "module lpeg not installed.  try 'brew install luarocks' or 'sudo apt-get install luarocks', then 'luarocks install lpeg'"
  exit
fi

lua -e 'if pcall(require,"cjson") then os.exit(0) else os.exit(1) end'
if [ $? -ne 0 ]; then
  echo "module cjson not installed.  try 'brew install luarocks' or 'sudo apt-get install luarocks', then 'luarocks install lua-cjson'"
  exit
fi

# If $USE_OMNIBUS_FILES is not set externally, default it to false
${USE_OMNIBUS_FILES:=1}
echo $USE_OMNIBUS_FILES

# If we are testing locally, use omnibus files
if [ $USE_OMNIBUS_FILES -eq 0 ]
then
  SCRIPT_DIR="../../files/private-chef-cookbooks/private-chef/templates/default/nginx/scripts"
  if [ ! -f resolver.lua ]; then
    ln -s $SCRIPT_DIR/resolver.lua.erb ./resolver.lua
  fi

  if [ ! -f routes.lua ]; then
    ln -s $SCRIPT_DIR/routes.lua.erb ./routes.lua
  fi

  if [ ! -f route_checks.lua ]; then
    ln -s $SCRIPT_DIR/route_checks.lua.erb ./route_checks.lua
  fi
else # Else, we are on a server install, use sane default
  SCRIPT_DIR="/var/opt/opscode/nginx/etc/scripts"
  if [ ! -f resolver.lua ]; then
    ln -s $SCRIPT_DIR/resolver.lua
  fi

  if [ ! -f routes.lua ]; then
    ln -s $SCRIPT_DIR/routes.lua
  fi

  if [ ! -f route_checks.lua ]; then
    ln -s $SCRIPT_DIR/route_checks.lua
  fi
fi

echo "Running tests"
echo "-------------"

lua run_tests.lua
exit $?
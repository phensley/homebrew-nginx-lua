Nginx + Lua

Installation

    brew tap phensley/nginx-lua
    brew install --debug --verbose nginx_lua

Sanity check

    ls -l $(brew --prefix)/Cellar/nginx-lua/1.7.7.1/

Startup

    $(brew --prefix)/bin/nginx-lua -p [working dir] -c [config]


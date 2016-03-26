Nginx + Lua

Installation

    brew tap phensley/nginx-lua
    brew install --debug --verbose nginx-lua

Sanity check

    ls -l $(brew --prefix)/Cellar/nginx-lua/1.9.7.4

Startup

    $(brew --prefix)/bin/nginx-lua -p [working dir] -c [config]


require 'formula'


# renamed to distinguish it from other openresty formulas
class NginxLua < Formula
  homepage 'http://openresty.org/'

  S3BASE = "http://s3.amazonaws.com/v6.nginx/sources"

  # this tracks the centos rpm's version number
  NGINX_VERSION = '0.2.0'

  stable do
    url "#{S3BASE}/openresty-1.9.7.4.tar.gz"
    sha256 'aa5dcae035dda6e483bc1bd3d969d7113205dc2d0a3702ece0ad496c88a653c5'
  end

# replaced by pure lua healthcheck module
#  resource "upstream_check" do
#    url "http://glonk.com/nginx_upstream_check_module-0.3.0.tar.gz"
#    sha1 '2fabab3e5c253e950a02202c883f0f9dfec01848'
#  end

  resource "jvm_route" do
    url "#{S3BASE}/nginx-upstream-jvm-route.tar.gz"
    sha256 '76be164dedc677965d9ee630def956b12eb3bc25643b0d56f215a78027238caa'
  end

  resource "lua_idn" do
    url "#{S3BASE}/lua-idn.tar.gz"
    sha256 'cdd9c090cc05014cbb2844730a33d9bd5f1bb3cfa85facd75f977f96e0056006'
  end

  resource "lua_marshal" do
    url "#{S3BASE}/lua-marshal.tar.gz"
    sha256 '19a4ed63717409eff460b444510ec8a684115a0f47dded60ebed542672f1500b'
  end

  resource "lua_mongo" do
    url "#{S3BASE}/lua-resty-mongol.tar.gz"
    sha256 '2a09250b1f9903ef4cbe65c8cf0928efeab3a473d1feb2f6dcbcc09b7d692cc8'
  end

  resource "lua_healthcheck" do
    url "#{S3BASE}/lua-resty-upstream-healthcheck.tar.gz"
    sha256 'ce1b62d13a888520e9e8cfd470a230df2d0d43faa8a31921ceb2c34c4e918deb'
  end

  resource "upstream_cache" do
    url  "#{S3BASE}/lua-upstream-cache-nginx-module.tar.gz"
    sha256 'abdf446981a683120a40028af59cb00677d2b55e66ecbd6d665b3926b751f897'
  end

  depends_on 'openssl'
  depends_on 'pcre'
  depends_on 'geoip'

  # options
  option 'with-debug', "Compile with support for debug logging but without proper gdb debugging symbols"

  skip_clean 'logs'

  def install

    args = [
      "--prefix=#{prefix}",
      '--with-http_ssl_module',
      '--with-luajit',
      '--with-pcre',
      '--with-pcre-jit',
      '--with-http_v2_module',
      '--with-http_gunzip_module',
      '--with-http_realip_module',
      '--with-http_geoip_module',
      '--with-http_gzip_static_module',
      '--with-http_stub_status_module',
      "--sbin-path=#{bin}/nginx-lua",
      "--conf-path=#{etc}/nginx-lua/nginx.conf",
      "--pid-path=#{var}/run/nginx-lua.pid",
      "--lock-path=#{var}/nginx-lua/nginx-lua.lock"
    ]

    args << "--with-http_dav_module" if build.with? 'webdav'
    args << "--with-http_geoip_module" if build.with? 'geoip'

    %w[jvm_route lua_idn lua_marshal lua_mongo lua_healthcheck upstream_cache].each do |r|
      resource(r).stage do
        (buildpath+r).install Dir["*"]
      end
    end

    cd buildpath/"bundle/nginx-1.9.7" do
# replaced by pure lua healthcheck
#      system "patch -p1 < #{buildpath}/upstream_check/check_1.9.2+.patch"
      system "patch -p0 < #{buildpath}/jvm_route/jvm_route.patch"
    end

# replaced by pure lua healthcheck
#    args << "--add-module=#{buildpath}/upstream_check"
    args << "--add-module=#{buildpath}/jvm_route"
    args << "--add-module=#{buildpath}/upstream_cache"

    # Debugging mode, unfortunately without debugging symbols
    if build.with? 'debug'
      args << '--with-debug'
      args << '--with-dtrace-probes'
      args << '--with-no-pool-patch'
      
      # this allows setting of `debug.sethook` in luajit
      args << '--with-luajit-xcflags=-DLUAJIT_ENABLE_CHECKHOOK'
      
      opoo "Openresty will be built --with-debug option, but without debugging symbols. For debugging symbols you have to compile it by hand."
    end

    system "./configure", *args

    system "make"
    system "make install"
 
    # build marshal native lua lib
    luajitpath = buildpath/"bundle/LuaJIT-2.1-20160108"
    cd buildpath/"lua_marshal" do
      system "gcc -O3 -I#{luajitpath}/src -o lmarshal.o -c lmarshal.c"
      system "gcc -bundle -undefined dynamic_lookup -o marshal.so lmarshal.o"
      cp "marshal.so", prefix/"lualib/"
    end

    # install a few extra lua modules
    cp buildpath/"lua_idn/idn.lua", prefix/"lualib/"
    cp_r buildpath/"lua_mongo/lib/resty/mongol", prefix/"lualib/resty/"

    (prefix/"lualib/squarespace.lua").write(lua_module())
  end

  def lua_module()
    <<-EOS.undent
    module('squarespace', package.seeall)
    nginx_version = "#{NGINX_VERSION}"
    EOS
  end
end


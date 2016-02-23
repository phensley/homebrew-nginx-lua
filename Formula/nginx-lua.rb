require 'formula'


# renamed to distinguish it from other openresty formulas
class NginxLua < Formula
  homepage 'http://openresty.org/'

  S3BASE = "http://s3.amazonaws.com/v6.nginx/sources"

  # this tracks the centos rpm's version number
  NGINX_VERSION = '0.1.1'

  stable do
    url "#{S3BASE}/openresty-1.9.7.3.tar.gz"
    sha1 '1a2029e1c854b6ac788b4d734dd6b5c53a3987ff'
  end

# replaced by pure lua healthcheck module
#  resource "upstream_check" do
#    url "http://glonk.com/nginx_upstream_check_module-0.3.0.tar.gz"
#    sha1 '2fabab3e5c253e950a02202c883f0f9dfec01848'
#  end

  resource "jvm_route" do
    url "#{S3BASE}/nginx-upstream-jvm-route.tar.gz"
    sha1 '2b68b0a511d04b86d24fe76b26acc333e0bf8abe'
  end

  resource "lua_idn" do
    url "#{S3BASE}/lua-idn.tar.gz"
    sha1 'e1ae68f27f8120be317712eb7c094ae7814c15be'
  end

  resource "lua_marshal" do
    url "#{S3BASE}/lua-marshal.tar.gz"
    sha1 '3f12977cbce9ebcfd69cf3c76aa5cd835abfc40d'
  end

  resource "lua_mongo" do
    url "#{S3BASE}/lua-resty-mongol.tar.gz"
    sha1 '5660aa39886f179bf5e4e502218f2be2aa1a802b'
  end

  resource "lua_healthcheck" do
    url "#{S3BASE}/lua-resty-upstream-healthcheck.tar.gz"
    sha1 '609c925e3c4611114a76222ca916722d7319736d'
  end

  resource "upstream_cache" do
    url  "#{S3BASE}/lua-upstream-cache-nginx-module.tar.gz"
    sha1 '9d53f81bb3ccaf7270ddeab65462febae3635b8e'
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


require 'formula'

# renamed to distinguish it from other openresty formulas
class NginxLua < Formula
  homepage 'http://openresty.org/'

  S3BASE = "http://s3.amazonaws.com/v6.nginx/sources"

  stable do
    url 'http://openresty.org/download/ngx_openresty-1.7.7.1.tar.gz'
    sha1 'bf70d465710f4d7a7aac24daa1841265bdc7e4e1'
  end

  resource "upstream_check" do
    url "#{S3BASE}/nginx_upstream_check_module.tar.gz"
    sha1 '36d5b11d744b9fd399cc79042445b63218087a35'
  end

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
    sha1 'cb34250a30e2f16cbc5ecb2580fdcbaa80321bad'
  end

  resource "upstream_cache" do
    url  "http://glonk.com/lua-upstream-cache-nginx-module.tar.gz"
    sha1 '9d53f81bb3ccaf7270ddeab65462febae3635b8e'
  end

  depends_on 'openssl'
  depends_on 'pcre'
  depends_on 'geoip' => :optional

  # options
  option 'with-iconv', "Compile with support for converting character encodings"
  option 'with-debug', "Compile with support for debug logging but without proper gdb debugging symbols"

  # nginx options
  option 'with-webdav', "Compile with ngx_http_dav_module"
  option 'with-gunzip', "Compile with ngx_http_gunzip_module"
  option 'with-geoip', "Compile with ngx_http_geoip_module"
  option 'with-stub_status', "Compile with ngx_http_stub_status_module"

  skip_clean 'logs'

  def install

    args = ["--prefix=#{prefix}",
      "--with-http_ssl_module",
      "--with-luajit",
      "--with-pcre",
      "--with-pcre-jit",
      "--with-http_gunzip_module",
      "--with-http_realip_module",
      "--with-http_stub_status_module",
      "--sbin-path=#{bin}/nginx-lua",
      "--conf-path=#{etc}/nginx-lua/nginx.conf",
      "--pid-path=#{var}/run/nginx-lua.pid",
      "--lock-path=#{var}/nginx-lua/nginx-lua.lock"
    ]

    args << "--with-http_dav_module" if build.with? 'webdav'
    args << "--with-http_geoip_module" if build.with? 'geoip'

    %w[upstream_check jvm_route lua_idn lua_marshal lua_mongo lua_healthcheck upstream_cache].each do |r|
      resource(r).stage do
        (buildpath+r).install Dir["*"]
      end
    end

    cd buildpath/"bundle/nginx-1.7.7" do
      system "patch -p1 < #{buildpath}/upstream_check/check_1.7.5+.patch"
      system "patch -p0 < #{buildpath}/jvm_route/jvm_route.patch"
    end

    args << "--add-module=#{buildpath}/upstream_check"
    args << "--add-module=#{buildpath}/jvm_route"
    args << "--add-module=#{buildpath}/upstream_cache"

    # Debugging mode, unfortunately without debugging symbols
    if build.with? 'debug'
      args << '--with-debug'
      args << '--with-dtrace-probes'
      args << '--with-no-pool-patch'
      
      # this allows setting of `debug.sethook` in luajit
      unless build.without? 'luajit'
        args << '--with-luajit-xcflags=-DLUAJIT_ENABLE_CHECKHOOK'
      end
      
      opoo "Openresty will be built --with-debug option, but without debugging symbols. For debugging symbols you have to compile it by hand."
    end

    # OpenResty options
    args << "--with-lua51" if build.without? 'luajit'

    args << "--with-http_postgres_module" if build.with? 'postgresql'
    args << "--with-http_iconv_module" if build.with? 'iconv'

    system "./configure", *args

    system "make"
    system "make install"
 
    # build marshal native lua lib
    luajitpath = buildpath/"bundle/LuaJIT-2.1-20141128"
    cd buildpath/"lua_marshal" do
      system "gcc -O3 -I#{luajitpath}/src -o lmarshal.o -c lmarshal.c"
      system "gcc -bundle -undefined dynamic_lookup -o marshal.so lmarshal.o"
      cp "marshal.so", prefix/"lualib/"
    end

    # install a few extra lua modules
    cp buildpath/"lua_idn/idn.lua", prefix/"lualib/"
    cp_r buildpath/"lua_mongo/lib/resty/mongol", prefix/"lualib/resty/"
  end
end


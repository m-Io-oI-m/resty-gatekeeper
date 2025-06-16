FROM openresty/openresty:alpine-fat

# 1. Install C toolchain + PCRE2 dev
RUN apk update && apk add --no-cache \
      build-base \
      pcre-dev 


RUN ls -l /usr/local/openresty/luajit/lib/lua

# 3. Install your Lua rocks
RUN luarocks install lua-resty-http
RUN luarocks install net-url
RUN luarocks install jsonschema
RUN luarocks install lua-resty-jwt

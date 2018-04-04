--
-- Created by IntelliJ IDEA.
-- User: zhangtao <ztao8607@gmail.com>
-- Date: 2018/4/3
-- Time: 下午4:51
--
local BasePlugin = require "kong.plugins.base_plugin"
local CachedHandler = BasePlugin:extend()
local redis = require "resty.redis"
local responses = require "kong.tools.responses"
local table_concat = table.concat

local ngx_log = ngx.log
local NGX_ERR = ngx.ERR
local NGX_DEBUG = ngx.DEBUG

local cache_key = "http://test/redis"

--https://github.com/wshirey/kong-plugin-response-cache

local function connect_to_redis(conf)
    local red = redis:new()

    red:set_timeout(60)

    local ok, err = red:connect("redis", 6379)
    if err then
        return nil, err
    end

    return red
end


local function write_red(premature, key, value)
    local red, err = connect_to_redis(conf)
    if err then
        ngx_log(NGX_ERR, "failed to connect to Redis: ", err)
        return
    end

    ok, err = red:set(key, value)
    if not ok then
        ngx.say("failed to set dog: ", err)
        return
    end
end

function CachedHandler:new()
    CachedHandler.super.new(self, "proxycache-plugin")
end

function CachedHandler:access(config)
    CachedHandler.super.access(self)
    ngx_log(NGX_ERR, ngx.var.scheme)
    ngx_log(NGX_ERR, ngx.var.uri)
    ngx_log(NGX_ERR, ngx.var.arg_code)

    local ctx = ngx.ctx
    ctx.rt_body_chunks = {}
    ctx.rt_body_chunk_number = 1

    --  $scheme$uri?code=$arg_code&time=$arg_time
    require 'pl.pretty'.dump(config)
    local red, err = connect_to_redis(conf)
    if err then
        ngx_log(NGX_ERR, "failed to connect to Redis: ", err)
        return
    end

    local cached_val, err = red:get(cache_key)
    if cached_val and cached_val ~= ngx.null then
        ngx_log(NGX_ERR, cached_val)
        ngx.print(cached_val)
        ngx.exit(200)
    end
end

function CachedHandler:body_filter(config)
    CachedHandler.super.body_filter(self)
    local ctx = ngx.ctx
    local chunk, eof = ngx.arg[1], ngx.arg[2]
    if eof then
        local body = table_concat(ctx.rt_body_chunks)
        ngx.arg[1] = body
        ngx.timer.at(0, write_red, cache_key, body)
        ngx_log(NGX_ERR, "Body_filter End")
    else
        ctx.rt_body_chunks[ctx.rt_body_chunk_number] = chunk
        ctx.rt_body_chunk_number = ctx.rt_body_chunk_number + 1
        ngx.arg[1] = nil
    end
end

--RewriteHandler.PRIORITY = 100
CachedHandler.VERSION = "v0.1.1"
return CachedHandler


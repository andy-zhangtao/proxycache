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

local cache_key = "default"
local expire_time = 60 * 60 * 1000
--https://github.com/wshirey/kong-plugin-response-cache

-- has_value 判断数组当中是否存val这个元素
-- has_value来自于status_code，因此需要把元素转换为Number类型
local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if tonumber(value) == val then
            return true
        end
    end

    return false
end

-- checkMethod 判断请求方法是否合法
local function checkMethod(config)

    for _, value in ipairs(config.methods) do
        ngx_log(NGX_ERR, value)
        if value == ngx.req.get_method() then
            return true
        end
    end

    return false
end

-- get_key 生成cache_key
-- 配置文件中的key中的变量必须以$开头. 例如$args_code, $scheme等
local function get_key(conf)
    local has_key = false
    if conf.key then
        ngx_log(NGX_ERR, conf.key)

        for s in string.gmatch(conf.key, '$([%w_-]+)') do
            has_key = true
            ngx_log(NGX_ERR, "Find key [" .. s .. "]")
            ngx_log(NGX_ERR, ngx.var[s])
            if s == "scheme" then
                cache_key = string.gsub(cache_key, "$" .. s, ngx.var[s] .. "://")
            else
                cache_key = string.gsub(cache_key, "$" .. s, ngx.var[s])
            end
        end

        if string.len(conf.key) >0 and not has_key then
            cache_key = conf.key
            has_key = true
        end

    end

    if not has_key then
        cache_key = "default"
    end

    expire_time = conf.cache_time * 60
    ngx_log(NGX_ERR, "cache_key = " .. cache_key)
end

-- connect_to_redis 链接redis服务器
-- 当前redis连接信息硬编码为redis:6379
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
        ngx.say("failed to set cache: ", err)
        return
    end

    red:expire(key, expire_time)
end

function CachedHandler:new()
    CachedHandler.super.new(self, "proxycache-plugin")
end

function CachedHandler:access(config)
    CachedHandler.super.access(self)
    --    ngx_log(NGX_ERR, ngx.var.scheme)
    --    ngx_log(NGX_ERR, ngx.var.uri)
    --    ngx_log(NGX_ERR, ngx.var.arg_code)

    get_key(config)

    local ctx = ngx.ctx
    ctx.rt_body_chunks = {}
    ctx.rt_body_chunk_number = 1

    --    require 'pl.pretty'.dump(config)
    local red, err = connect_to_redis(conf)
    if err then
        ngx_log(NGX_ERR, "failed to connect to Redis: ", err)
        return
    end

    if checkMethod(config) then
        local cached_val, err = red:get(cache_key)
        if cached_val and cached_val ~= ngx.null then
            ngx_log(NGX_ERR, cached_val)
            ngx.print(cached_val)
            ngx.exit(200)
        end
    end
end

function CachedHandler:body_filter(config)
    CachedHandler.super.body_filter(self)
    local ctx = ngx.ctx
    local chunk, eof = ngx.arg[1], ngx.arg[2]
    if eof then
        local body = table_concat(ctx.rt_body_chunks)
        ngx.arg[1] = body
        if has_value(config.status_code, ngx.status) and checkMethod(config) then
            ngx.timer.at(0, write_red, cache_key, body)
        end
    else
        ctx.rt_body_chunks[ctx.rt_body_chunk_number] = chunk
        ctx.rt_body_chunk_number = ctx.rt_body_chunk_number + 1
        ngx.arg[1] = nil
    end
end

--RewriteHandler.PRIORITY = 100
CachedHandler.VERSION = "v0.1.1"
return CachedHandler


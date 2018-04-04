--
-- Created by IntelliJ IDEA.
-- User: zhangtao <ztao8607@gmail.com>
-- Date: 2018/4/3
-- Time: 下午4:49
--

--[[用户自定义缓存规则
-- ]]
return {
    no_consumer = true,
    fields = {
        methods = {
            type = "array",
            required = true,
        },
        key = {
            type = "string",
            required = true,
        },
        status_code = {
            type = "array",
            required = true,
        },
        cache_time = {
            type = "number",
            required = true,
        },
        min_uses = {
            type = "number",
            required = false,
        }
    },
    self_check = check --[[这里应该是个bug, 设定的self_check返回给调用方的是"function"]]
}



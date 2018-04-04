# proxycache
> A lua plugin for kong gateway

部分实现参考`https://github.com/wshirey/kong-plugin-response-cache`

## Rule

缓存数据规则：
1. 如果请求方法与设定方法符合, 并且缓存中存在相同Key时，返回缓存数据.
2. 如果请求方法与设定方法符合, 并且返回的响应码与设定的响应码相同时, 缓存当前数据

## Configure

* methods: 支持的方法列表. 当请求方法在此列表中时, 才会判断是否需要返回缓存数据.
* min uses: 暂不生效
* cache time: 缓存时间, 单位分钟
* status code: 缓存响应码表. 当响应码在此列表中，并且方法相同时，才会缓存当前数据
* key: 缓存key。遵从nginx变量规则,支持所有Nginx变量

## ChangeLog

* 0.1.1
  - 支持基本缓存规则
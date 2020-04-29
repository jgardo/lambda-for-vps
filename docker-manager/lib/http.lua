module("http", package.seeall)
local cjson = require("cjson")

function get(url)
    local res = ngx.location.capture(url, { 
        method = ngx.HTTP_GET 
    })
    local result = cjson.decode(res.body) 
    return res.status, result
end

function decodeJson(body) 
    local result = nil
    if body ~= nil and body ~= '' then
        result = cjson.decode(body) 
    end

    return result
end

function post(url, body)
    local serializedBody = cjson.encode(body);
    local res = ngx.location.capture(url, { 
        method = ngx.HTTP_POST, 
        body = serializedBody
    })
    return res.status, decodeJson(res.body)
end

function put(url, body)
    local serializedBody = cjson.encode(body);
    local res = ngx.location.capture(url, { 
        method = ngx.HTTP_PUT, 
        body = serializedBody
    })
    return res.status, decodeJson(res.body)
end

function delete(url)
    local res = ngx.location.capture(url, { 
        method = ngx.HTTP_DELETE 
    })
    return res.status, decodeJson(res.body)
end

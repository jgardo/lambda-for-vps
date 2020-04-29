module("externaldocker", package.seeall)
local cjson = require("cjson")
local http = require "resty.http"
local hc = http:new()

function initializeJwt(username, password)
    local requestBody = cjson.encode({ username = username, password = password })
    local ok, code, headers, status, body  = hc:request {
        url = 'http://127.0.0.1/portainer/api/auth',
        method = "POST",
        body = requestBody
    }
    local jwtResult = cjson.decode(body)
    return jwtResult.jwt;
end

function retrieveLocalEndpointId(jwt)
    local ok, code, headers, status, body  = hc:request {
        url = 'http://127.0.0.1/portainer/api/endpoints',
        method = "GET",
        headers = { Authorization = "Bearer " .. jwt}
    }
    local localEndpoints = cjson.decode(body)
    for i,localEndpoint in ipairs(localEndpoints) do 
        for key in pairs(localEndpoint) do 
            if key == "Name" and localEndpoint[key] == "local" then
                local value = localEndpoint["Id"]
                return value
            end
        end
    end
end

function stopStackWithName(jwt, endpointId, stackName)
    local ok, code, headers, status, body  = hc:request {
        url = "http://127.0.0.1/portainer/api/endpoints/" .. endpointId .. '/docker/containers/json?all=1&filters=%7B%22label%22:%5B%22com.docker.compose.project%3D' .. stackName ..'%22%5D%7D',
        method = "GET", -- POST or GET
        headers = { Authorization = "Bearer " .. jwt}
    }
    local containers = cjson.decode(body)
    for i,container in ipairs(containers) do 
        if container["State"] == "running" then
            local containerId = container["Id"]
            ok, code, headers, status, body  = hc:request {
                url = 'http://127.0.0.1/portainer/api/endpoints/' .. endpointId .. '/docker/containers/' .. containerId .. '/stop',
                method = "POST",
                headers = { Authorization = "Bearer " .. jwt},
                body = '{}'
            }
        end
    end    
end
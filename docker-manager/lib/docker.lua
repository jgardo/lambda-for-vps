module("docker", package.seeall)
local http = require('http')

function initializeAdmin(username, password)
    local status, result = http.post('/portainer/api/users/admin/init', { username = username, password = password });
    return status, result
end

function initializeJwt(username, password)
    local status, jwtResult = http.post('/portainer/api/auth',{ username = username, password = password });
    return jwtResult.jwt;
end

function setAuthorizationHeader(jwt)   
    ngx.req.set_header('Authorization', 'Bearer ' .. jwt);
end

function clearAuthorizationHeader(jwt)   
    ngx.req.clear_header('Authorization');
end

function retrieveLocalEndpointId()
    local endpointsStatus, localEndpoints = http.get('/portainer/api/endpoints')
    if  next(localEndpoints) == nil then
        ngx.req.set_header('Content-Type', 'multipart/form-data; boundary=----WebKitFormBoundaryKdEnRy9bUb7FtQSo');

        local res = ngx.location.capture('/portainer/api/endpoints', {
            method = ngx.HTTP_POST, 
            body =  '------WebKitFormBoundaryKdEnRy9bUb7FtQSo\nContent-Disposition: form-data; name="Name"\n\nlocal\n------WebKitFormBoundaryKdEnRy9bUb7FtQSo\nContent-Disposition: form-data; name="EndpointType"\n\n1\n------WebKitFormBoundaryKdEnRy9bUb7FtQSo\nContent-Disposition: form-data; name="URL"\n\n\n------WebKitFormBoundaryKdEnRy9bUb7FtQSo\nContent-Disposition: form-data; name="PublicURL"\n\n\n------WebKitFormBoundaryKdEnRy9bUb7FtQSo\nContent-Disposition: form-data; name="GroupID"\n\n1\n------WebKitFormBoundaryKdEnRy9bUb7FtQSo\nContent-Disposition: form-data; name="Tags"\n\n[]\n------WebKitFormBoundaryKdEnRy9bUb7FtQSo\nContent-Disposition: form-data; name="TLS"\n\nfalse\n------WebKitFormBoundaryKdEnRy9bUb7FtQSo--'
        })
        ngx.req.clear_header('Content-Type');

        endpointsStatus, localEndpoints = http.get('/portainer/api/endpoints')
    end

    for i,localEndpoint in ipairs(localEndpoints) do 
        for key in pairs(localEndpoint) do 
            if key == "Name" and localEndpoint[key] == "local" then
                local value = localEndpoint["Id"]
                return value
            end
        end
    end
end

function findStackWithName(endpointId, name)
    local stacksStatus, stacks = http.get('/portainer/api/stacks')
    for i,stack in ipairs(stacks) do 
        if stack["Name"] == name then
            local value = stack["Id"]
            return value
        end
    end
end

function findNetworkForStackWithName(endpointId, name)
    local status, stackDetails = http.get('/portainer/api/endpoints/'.. endpointId ..'/docker/containers/json?all=1&filters=%7B%22label%22:%5B%22com.docker.compose.project%3D' .. name .. '%22%5D%7D')
    if next(stackDetails) ~= nil then
        local value = stackDetails[1]["NetworkSettings"]["Networks"]["bridge"]["Gateway"]
        ngx.log(ngx.ERR, value)
        return value
    end
end

function deletePreviousStackWithName(endpointId, name)
    local stackId = findStackWithName(endpointId, name)
    if stackId ~= nil then
        local deleteStatus, result = http.delete('/portainer/api/stacks/' .. stackId);
        return deleteStatus, result;
    end
end

function restartStackWithName(endpointId, name, dockerComposeFilePath)
    local status, containers = http.get('/portainer/api/endpoints/' .. endpointId .. '/docker/containers/json?all=1&filters=%7B%22label%22:%5B%22com.docker.compose.project%3D' .. name ..'%22%5D%7D')

    if next(containers) == nil then
        deployStack(endpointId, name, dockerComposeFilePath)
    end
    
    local atLeastOneRestarted = false
    for i,container in ipairs(containers) do 
        if container["State"] ~= "running" then
            local containerId = container["Id"]
            local body = { } 
            local status, result = http.post('/portainer/api/endpoints/' .. endpointId .. '/docker/containers/' .. containerId .. '/start', body)
            atLeastOneRestarted = true
        end
    end
    return atLeastOneRestarted
end

function stopStackWithName(endpointId, name)
    local status, containers = http.get('/portainer/api/endpoints/' .. endpointId .. '/docker/containers/json?all=1&filters=%7B%22label%22:%5B%22com.docker.compose.project%3D' .. name ..'%22%5D%7D')

    for i,container in ipairs(containers) do 
        if container["State"] == "running" then
            local containerId = container["Id"]
            local status, result = http.post('/portainer/api/endpoints/' .. endpointId .. '/docker/containers/' .. containerId .. '/stop', {})
        end
    end
end

function deployStack(endpointId, stackName, dockerComposeFilePath)
    deletePreviousStackWithName(endpointId, stackName)
    local f = io.open(dockerComposeFilePath, "r")
    local content = f:read("*a")
    f:close()
    
    local newStackRequest = {
        Name = stackName,
        StackFileContent = content   
    }    
    local status, result = http.post('/portainer/api/stacks?type=2&method=string&endpointId=' .. endpointId, newStackRequest)
    return status, result;
end
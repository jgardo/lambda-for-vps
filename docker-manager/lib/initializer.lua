module("initializer", package.seeall)
local docker = require('docker')

function log(string)
    ngx.log(ngx.ERR, string);
end

function initializeAdmin(username, password)
    local state = ngx.shared.state;
    local adminInitialized = state:get("adminInitialized");
    
    if state:get("adminInitialized") == nil then 
        local status, result = docker.initializeAdmin(username, password)
        local succ, err, forcible = state:set("adminInitialized", "true")
    end
end

function authorizeDocker(username, password)
    local jwt = docker.initializeJwt(username, password)
    docker.setAuthorizationHeader(jwt)
    return jwt
end

function retrieveLocalEndpointId() 
    local state = ngx.shared.state;
    local localEndpointId = state:get("localEndpointId");
    
    if localEndpointId == nil then 
        localEndpointId = docker.retrieveLocalEndpointId()
        local succ, err, forcible = state:set("localEndpointId", localEndpointId)
    end
    return localEndpointId
end

function restartStackWithName(localEndpointId, stackName, dockerComposeFilePath, afterRestartSleep)
    local atLeastOneRestarted = docker.restartStackWithName(localEndpointId, stackName, dockerComposeFilePath)
    if atLeastOneRestarted == true then
        ngx.sleep(afterRestartSleep)
    end
end

function updateIp(localEndpointId, stackName)
    local ips = ngx.shared.ips;
    local networkIp = ips:get(stackName)
    if networkIp == nil then 
        networkIp = docker.findNetworkForStackWithName(localEndpointId, stackName)
        if networkIp ~= nil then 
            local succ, err, forcible = ips:set(stackName, networkIp)
        end
    end
    return networkIp
end

function updateTimeToKill(initParams)
    local stackName = initParams.stackName;
    local offset = initParams.killAfter;
    local timeToKill = ngx.shared.timeToKill;
    local newTimeToKill = ngx.time() + offset;
    local networkIp = timeToKill:set(stackName, newTimeToKill);
end

function init(initParams)
    local username = os.getenv('portainerLogin');
    local password = os.getenv('portainerPassword');
    local stackName = initParams.stackName;
    local afterRestartSleep = initParams.afterRestartSleep;
    local dockerComposeFilePath = initParams.dockerComposeFilePath;

    local state = ngx.shared.appState:get(stackName);

    while(state == 'initializing')
    do
        ngx.sleep(1)
        state = ngx.shared.appState:get(stackName);
    end

    if state == nil or state == 'dying' then
        while(state == 'dying')
        do
            ngx.sleep(1)
            state = ngx.shared.appState:get(stackName);
        end
        ngx.shared.appState:set(stackName, 'initializing');
        ngx.log(ngx.INFO, 'Initializing stack "' .. stackName .. '".' )

        initializeAdmin(username, password) 
        local jwt = authorizeDocker(username, password) 
    
        local localEndpointId = retrieveLocalEndpointId();    
        
        restartStackWithName(localEndpointId, stackName, dockerComposeFilePath, afterRestartSleep)
        ngx.var.ip = updateIp(localEndpointId, stackName)  
        ngx.shared.appState:set(stackName, 'running');
        ngx.log(ngx.INFO, 'Stack "' .. stackName .. '" is running.' )
    else
        local localEndpointId = retrieveLocalEndpointId();    
        
        ngx.var.ip = updateIp(localEndpointId, stackName)      
    end
end
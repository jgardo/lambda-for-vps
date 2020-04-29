module("killer", package.seeall)
local externalDocker = require("externaldocker")

local function retrieveLocalEndpointId(jwt) 
    local state = ngx.shared.state;
    local localEndpointId = state:get("localEndpointId");
    
    return localEndpointId
end

function scheduleKilling(initParams)
    local username = os.getenv('portainerLogin');
    local password = os.getenv('portainerPassword');
    local stackName = initParams.stackName;
end

local function killAllThatShouldBeKilled(premature) 
    local username = os.getenv('portainerLogin');
    local password = os.getenv('portainerPassword');

    local allScheduledMurders = ngx.shared.timeToKill:get_keys(0)
    local now = ngx.time()

    for i,stackName in ipairs(allScheduledMurders) do 
        local killingTime = ngx.shared.timeToKill:get(stackName);
        local state = ngx.shared.appState:get(stackName);

        if now > killingTime and state == "running" then
            ngx.shared.appState:set(stackName, 'dying');
            ngx.log(ngx.INFO, 'Shuting down stack "' .. stackName .. '".' )

            local jwt = externalDocker.initializeJwt(username, password)
            local localEndpointId = retrieveLocalEndpointId(jwt);    
            externalDocker.stopStackWithName(jwt, localEndpointId, stackName)    

            ngx.shared.timeToKill:delete(stackName);
            ngx.shared.appState:delete(stackName);
            ngx.log(ngx.INFO, 'Stack "' .. stackName .. '" is stopped.' )
        end
    end
end

ngx.timer.every(5, killAllThatShouldBeKilled)
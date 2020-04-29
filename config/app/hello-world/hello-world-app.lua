local initializer = require('initializer')
local killer = require('killer')

local initParams = {
    stackName = "hello", -- informative name of app used in Portainer
    afterRestartSleep = 2, -- constant time in seconds to wait for initialization of container after starting it
    killAfter = 15, -- time in seconds to kill all containers in docker-compose after last request
    dockerComposeFilePath = "/hello-world/docker-compose.yml" -- path to docker-compose.yml file to be deployed 
}
initializer.init(initParams);
initializer.updateTimeToKill(initParams);

killer.scheduleKilling(initParams)
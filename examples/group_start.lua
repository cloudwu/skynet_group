local skynet = require "skynet"
local group = require "group"

local function init(id)
	print("Start group", id)
	group.newservice("echoserver")
	print(group.call("echoserver", "echo", "hello"))
end

group.start {
	init = init
}

local skynet = require "skynet"
local group = require "group"

local function list(g)
	local groupname = skynet.call(g, "lua", "name")
	local l = skynet.call(g, "lua", "services")
	for addr, name in pairs(l) do
		print(groupname, name, addr)
	end
end

skynet.start(function()
	local a = group.newgroup("GROUPA", "group_start", 1)
	local b = group.newgroup("GROUPB", "group_start", 2)
	local c = group.newgroup("GROUPC", "group_start", 3)
	list(a)
	list(b)
	list(c)
end)

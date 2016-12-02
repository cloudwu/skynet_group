local skynet = require "skynet"

local group = {}
local name = (...)
local launch_queue = {}
local name_map = {}
local services = {}

local function ret(...)
	skynet.ret(skynet.pack(...))
end

local function link_service(addr)
	pcall(skynet.call, addr, "lua", "_link")
	services[addr] = nil
end

local function new_service(name, ...)
	local addr = skynet.newservice(name)
	skynet.call(addr, "lua", "_init", skynet.self(), ...)
	services[addr] = name
	skynet.fork(link_service, addr)
	return addr
end

local function launch_service(name, ...)
	local ok, addr = pcall(new_service, name, ...)
	if ok then
		name_map[name] = addr
		for _, resp in ipairs(launch_queue[name]) do
			resp(true, addr)
		end
	else
		for _, resp in ipairs(launch_queue[name]) do
			resp(false)
		end
	end
	launch_queue[name] = nil
end

function group.query(name)
	if name_map[name] then
		ret(name_map[name])
		return
	end
	if launch_queue[name] == nil then
		local queue = { skynet.response() }
		skynet.fork(launch_service, name)
		launch_queue[name] = queue
	else
		table.insert(launch_queue[name], skynet.response())
	end
end

function group.launch(name, ...)
	if launch_queue[name] == nil then
		-- first launch, name it
		local queue = { skynet.response() }
		skynet.fork(launch_service, name, ...)
		launch_queue[name] = queue
	else
		-- launch multi copy
		local addr = skynet.newservice(name)
		skynet.call(addr, "lua", "_init", skynet.self(), ...)
		ret(addr)
	end
end

function group.name()
	ret(name)
end

function group.services()
	ret(services)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = assert(group[cmd])
		f(...)
	end)
end)

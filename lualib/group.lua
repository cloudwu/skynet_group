local skynet = require "skynet"

local group_service = setmetatable({} , {
	__index = function(t, k)
		if type(k) == "number" then
			t[k] = k
			return k
		end
	end
	})

local group = { service = group_service }
local groupd = nil
local send_queue = {}

function group.query(group_addr, name)
	if type(group_addr) == "string" then
		assert(name == nil)
		name = group_addr
		group_addr = groupd
	end
	local addr = skynet.call(group_addr, "lua", "query", name)
	group_service[name] = addr
	return addr
end

local function send_query(name)
	local queue = send_queue[name]
	if queue == nil then
		return
	end
	local addr = group.query(name)
	for _, args in ipairs(queue) do
		skynet.send(addr, "lua", table.unpack(args, 1, args.n))
	end
	send_queue[name] = nil
end

function group.call(addr, ...)
	local addr_id = group_service[addr]
	if addr_id == nil then
		addr_id = group.query(addr)
	end
	return skynet.call(addr_id, "lua", ...)
end

function group.send(addr, ...)
	if send_queue[addr] then
		table.insert(send_queue[addr], table.pack(...))
	else
		local addr_id = group_service[addr]
		if addr_id then
			skynet.send(addr_id, "lua", ...)
		else
			local queue = { table.pack(...) }
			send_queue[addr] = queue
			skynet.fork(send_query, addr)
		end
	end
end

function group.newgroup(groupname, bootname, ...)
	local g = skynet.newservice("groupd", groupname)
	local boot = skynet.call(g, "lua", "launch", bootname, ...)
	skynet.send(boot, "debug", "EXIT")	-- exit boot service
	return g
end

function group.name()
	return skynet.call(groupd, "lua", "name")
end

function group.newservice(name, ...)
	return skynet.call(groupd, "lua", "launch", name, ...)
end

-- server {
--	service = {}, -- optional
--	init = function,
--	command = {},
-- }
function group.start(server)
	local command = {}

	function command._init(group_service, ...)
		groupd = group_service
		if server.service then
			for _, name in ipairs(server.service) do
				group.query(name)
			end
		end
		if server.command then
			for cmd, func in pairs(server.command) do
				command[cmd] = func
			end
		end
		if server.init then
			server.init(...)
		end
	end

	skynet.start(function()
		skynet.dispatch("lua", function(session, address, cmd, ...)
			if cmd == "_link" then
				-- never return, raise error when exit
				return
			end
			local f = assert(command[cmd])
			if session == 0 then
				f(...)
			else
				skynet.ret(skynet.pack(f(...)))
			end
		end)
	end)
end

return group

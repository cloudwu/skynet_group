local group = require "group"

local echo = {}

local groupname

function echo.echo(...)
	return groupname, ...
end

local function init()
	groupname = group.name()
	print("Echo server in", groupname)
end

group.start {
	init = init,
	command = echo,
}

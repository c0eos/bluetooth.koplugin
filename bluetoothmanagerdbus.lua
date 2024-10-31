local logger = require("logger")
local _ = require("gettext")

---@class BluetoothManager
local BluetoothManager = {
	adapter_path = "/org/bluez/hci0", -- BT adapter path TODO: automate
	adapter_interface = "org.bluez.Adapter1", -- interface for dbus TODO: automate with Introspect?
	dbus_dest = "com.kobo.mtk.bluedroid", -- dest for dbus-send TODO: automate
}

---@protected
---@param command string
---@return string
function BluetoothManager:_run_dbus_command(command)
	local handle = io.popen(command .. " 2>&1")
	local result = handle:read("*a")
	handle:close()

	logger.warn("bluetooth result", result)
	return result
end

---@protected
---@param dest string
---@param device_path string
---@param interface string
---@param method string
---@param args string[]
---@return string
function BluetoothManager:_create_dbus_command(dest, device_path, interface, method, args)
	local command = "dbus-send --system --dest="
		.. dest
		.. " --type=method_call --print-reply "
		.. device_path
		.. " "
		.. interface
		.. "."
		.. method

	for _, arg in ipairs(args or {}) do
		command = command .. " " .. arg
	end

	logger.warn("bluetooth command:", command)
	return command
end

---@protected
---@param result string
---@return BluetoothItem[]
function BluetoothManager:_parseManagedObjects(result)
	local objects = {}

	local current_object = nil
	local current_property = nil

	for line in result:gmatch("[^\n]+") do
		local object_path = line:match('^%s+object path "(.*)"')
		if object_path then
			current_object = { path = object_path }
			current_property = nil
			table.insert(objects, current_object)
		end

		local interface_name = line:match('^%s+string "(.*)"')
		if interface_name and not current_object.interface then
			current_object["interface"] = interface_name
			current_property = nil
		elseif interface_name then
			current_property = interface_name
		end

		local type, value = line:match("^%s+variant%s+([%w%d]*)%s+(.*)$")

		if current_property and value then
			if type == "boolean" then
				value = value == "true"
			elseif type == "int16" or type == "int32" or type == "uint16" or type == "uint32" then
				value = tonumber(value)
			else
				value = value:match('"(.*)"')
			end
			current_object[current_property] = value
			current_property = nil
		end
	end

	return objects
end

-- GetManagedObjects
---@protected
---@return any
function BluetoothManager:_getManagedObjects()
	local command =
		self:_create_dbus_command(self.dbus_dest, "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects")
	return self:_run_dbus_command(command)
end

-- Discover devices
function BluetoothManager:startDiscovery()
	local command =
		self:_create_dbus_command(self.dbus_dest, self.adapter_path, self.adapter_interface, "StartDiscovery")
	return self:_run_dbus_command(command)
end

function BluetoothManager:stopDiscovery()
	local command =
		self:_create_dbus_command(self.dbus_dest, self.adapter_path, self.adapter_interface, "StopDiscovery")
	return self:_run_dbus_command(command)
end

-- Set device as trusted
---@param device BluetoothItem
---@param value boolean
---@return boolean
function BluetoothManager:setTrusted(device, value)
	local device_path = device.path
	return self:_setProperty(device_path, "org.bluez.Device1", "Trusted", value)
end

-- Pair with a device
---@param device BluetoothItem
---@return string
function BluetoothManager:pairDevice(device)
	local device_path = device.path
	local command = self:_create_dbus_command(self.dbus_dest, device_path, "org.bluez.Device1", "Pair")
	return self:_run_dbus_command(command)
end

-- Connect to a device
---@param device BluetoothItem
---@return string
function BluetoothManager:connectDevice(device)
	local device_path = device.path
	local command = self:_create_dbus_command(self.dbus_dest, device_path, "org.bluez.Device1", "Connect")
	return self:_run_dbus_command(command)
end

-- Disconnect from a device
---@param device BluetoothItem
---@return string
function BluetoothManager:disconnectDevice(device)
	local device_path = device.path
	local command = self:_create_dbus_command(self.dbus_dest, device_path, "org.bluez.Device1", "Disconnect")
	return self:_run_dbus_command(command)
end

-- Forget a device
---@param device BluetoothItem
---@return string
function BluetoothManager:removeDevice(device)
	local device_path = device.path
	local args = {
		"objpath:" .. device_path,
	}
	local command =
		self:_create_dbus_command(self.dbus_dest, self.adapter_path, self.adapter_interface, "RemoveDevice", args)
	return self:_run_dbus_command(command)
end

-- Power on or off the adapter
---@protected
---@param value boolean
---@return boolean
function BluetoothManager:_setPowered(value)
	return self:_setProperty(self.adapter_path, self.adapter_interface, "Powered", value)
end

---@return boolean
function BluetoothManager:setBluetoothOn()
	return self:_setPowered(true)
end

---@return boolean
function BluetoothManager:setBluetoothOff()
	return self:_setPowered(false)
end

---@return boolean
function BluetoothManager:isBluetoothOn()
	return self:_getProperty(self.adapter_path, self.adapter_interface, "Powered")
end

-- Get device or adapter property (e.g., Powered, Connected, Paired, etc.)
---@protected
---@param device_path string
---@param interface string
---@param property string
---@return boolean | number | string
function BluetoothManager:_getProperty(device_path, interface, property)
	local args = {
		"string:'" .. interface .. "'",
		"string:'" .. property .. "'",
	}
	local command =
		self:_create_dbus_command(self.dbus_dest, device_path, "org.freedesktop.DBus.Properties", "Get", args)
	local output = self:_run_dbus_command(command)
	local result = output:match("variant%s+(.+)")
	return self:_parseResult(result)
end

---@protected
---@param result string
---@return boolean | number | string
function BluetoothManager:_parseResult(result)
	return result
end

-- Set device or adapter property
---@protected
---@param device_path string
---@param interface string
---@param property string
---@param value any
---@return boolean | number | string
function BluetoothManager:_setProperty(device_path, interface, property, value)
	local args = {
		"string:'" .. interface .. "'",
		"string:'" .. property .. "'",
		"variant:boolean:" .. tostring(value),
	}
	local command =
		self:_create_dbus_command(self.dbus_dest, device_path, "org.freedesktop.DBus.Properties", "Set", args)
	local output = self:_run_dbus_command(command)
	local result = self:_getProperty(device_path, interface, property)
	return result
end

return BluetoothManager

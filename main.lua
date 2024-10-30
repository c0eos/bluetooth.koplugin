--[[--
This is a plugin to manage Bluetooth.

@module koplugin.Bluetooth
--]]
--

local Dispatcher = require("dispatcher")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputContainer = require("ui/widget/container/inputcontainer")
local Device = require("device")
local EventListener = require("ui/widget/eventlistener")
local Event = require("ui/event") -- Add this line
local logger = require("logger")

-- local BTKeyManager = require("BTKeyManager")

local _ = require("gettext")

-- local Bluetooth = EventListener:extend{
local Bluetooth = InputContainer:extend({
	name = "Bluetooth",
	input_device_path = "/dev/input/event3", -- Device path
	adapter_path = "/org/bluez/hci0", -- BT adapter path
	dbus_dest = "com.kobo.mtk.bluedroid", -- dest for dbus-send
})

function Bluetooth:onDispatcherRegisterActions()
	Dispatcher:registerAction(
		"bluetooth_on_action",
		{ category = "none", event = "BluetoothOn", title = _("Bluetooth On"), general = true }
	)
	Dispatcher:registerAction(
		"bluetooth_off_action",
		{ category = "none", event = "BluetoothOff", title = _("Bluetooth Off"), general = true }
	)
	Dispatcher:registerAction(
		"refresh_pairing_action",
		{ category = "none", event = "RefreshPairing", title = _("Refresh Device Input"), general = true }
	) -- New action
	Dispatcher:registerAction(
		"connect_to_device_action",
		{ category = "none", event = "ConnectToDevice", title = _("Connect to Device"), general = true }
	) -- New action
end

function Bluetooth:registerKeyEvents()
	self.key_events.BTGotoNextChapter = { { "BTGotoNextChapter" }, event = "BTGotoNextChapter" }
	self.key_events.BTGotoPrevChapter = { { "BTGotoPrevChapter" }, event = "BTGotoPrevChapter" }
	self.key_events.BTDecreaseFontSize = { { "BTDecreaseFontSize" }, event = "BTDecreaseFontSize" }
	self.key_events.BTIncreaseFontSize = { { "BTIncreaseFontSize" }, event = "BTIncreaseFontSize" }
	self.key_events.BTToggleBookmark = { { "BTToggleBookmark" }, event = "BTToggleBookmark" }
	self.key_events.BTIterateRotation = { { "BTIterateRotation" }, event = "BTIterateRotation" }
	self.key_events.BTBluetoothOff = { { "BTBluetoothOff" }, event = "BTBluetoothOff" }
	self.key_events.BTRight = { { "BTRight" }, event = "BTRight" }
	self.key_events.BTLeft = { { "BTLeft" }, event = "BTLeft" }
	self.key_events.BTIncreaseBrightness = { { "BTIncreaseBrightness" }, event = "BTIncreaseBrightness" }
	self.key_events.BTDecreaseBrightness = { { "BTDecreaseBrightness" }, event = "BTDecreaseBrightness" }
	self.key_events.BTIncreaseWarmth = { { "BTIncreaseWarmth" }, event = "BTIncreaseWarmth" }
	self.key_events.BTDecreaseWarmth = { { "BTDecreaseWarmth" }, event = "BTDecreaseWarmth" }
	self.key_events.BTNextBookmark = { { "BTNextBookmark" }, event = "BTNextBookmark" }
	self.key_events.BTPrevBookmark = { { "BTPrevBookmark" }, event = "BTPrevBookmark" }
	self.key_events.BTLastBookmark = { { "BTLastBookmark" }, event = "BTLastBookmark" }
	self.key_events.BTToggleNightMode = { { "BTToggleNightMode" }, event = "BTToggleNightMode" }
	self.key_events.BTToggleStatusBar = { { "BTToggleStatusBar" }, event = "BTToggleStatusBar" }
end

function Bluetooth:onBTGotoNextChapter()
	UIManager:sendEvent(Event:new("GotoNextChapter"))
end

function Bluetooth:onBTGotoPrevChapter()
	UIManager:sendEvent(Event:new("GotoPrevChapter"))
end

function Bluetooth:onBTDecreaseFontSize()
	UIManager:sendEvent(Event:new("DecreaseFontSize", 2))
end

function Bluetooth:onBTIncreaseFontSize()
	UIManager:sendEvent(Event:new("IncreaseFontSize", 2))
end

function Bluetooth:onBTToggleBookmark()
	UIManager:sendEvent(Event:new("ToggleBookmark"))
end

function Bluetooth:onBTIterateRotation()
	UIManager:sendEvent(Event:new("IterateRotation"))
end

function Bluetooth:onBTBluetoothOff()
	UIManager:sendEvent(Event:new("BluetoothOff"))
end

function Bluetooth:onBTRight()
	UIManager:sendEvent(Event:new("GotoViewRel", 1))
end

function Bluetooth:onBTLeft()
	UIManager:sendEvent(Event:new("GotoViewRel", -1))
end

function Bluetooth:onBTIncreaseBrightness()
	UIManager:sendEvent(Event:new("IncreaseFlIntensity", 10))
end

function Bluetooth:onBTDecreaseBrightness()
	UIManager:sendEvent(Event:new("DecreaseFlIntensity", 10))
end

function Bluetooth:onBTIncreaseWarmth()
	UIManager:sendEvent(Event:new("IncreaseFlWarmth", 1))
end

function Bluetooth:onBTDecreaseWarmth()
	UIManager:sendEvent(Event:new("IncreaseFlWarmth", -1))
end

function Bluetooth:onBTNextBookmark()
	UIManager:sendEvent(Event:new("GotoNextBookmarkFromPage"))
end

function Bluetooth:onBTPrevBookmark()
	UIManager:sendEvent(Event:new("GotoPreviousBookmarkFromPage"))
end

function Bluetooth:onBTLastBookmark()
	UIManager:sendEvent(Event:new("GoToLatestBookmark"))
end

function Bluetooth:onBTToggleNightMode()
	UIManager:sendEvent(Event:new("ToggleNightMode"))
end

function Bluetooth:onBTToggleStatusBar()
	UIManager:sendEvent(Event:new("ToggleFooterMode"))
end

function Bluetooth:init()
	self:onDispatcherRegisterActions()
	self.ui.menu:registerToMainMenu(self)

	self:registerKeyEvents()
end

function Bluetooth:addToMainMenu(menu_items)
	menu_items.bluetooth = {
		text = _("Bluetooth"),
		sorting_hint = "network",
		sub_item_table = {
			{
				text = _("Bluetooth"),
				keep_menu_open = true,
				checked_func = function()
					return self:isBluetoothOn()
					-- return false
				end,
				callback = function(touchmenu_instance)
					self:onBluetoothToggle()
					touchmenu_instance:updateItems()
				end,
			},
			{
				text = _("Reconnect to Device"),
				keep_menu_open = true,
				enabled_func = function()
					return self:isBluetoothOn()
				end,
				callback = function()
					self:onConnectToDevice()
				end,
			},
			{
				text = _("Refresh Device Input"), -- New menu item
				keep_menu_open = true,
				callback = function()
					self:onRefreshPairing()
				end,
			},
		},
	}
end

function Bluetooth:onBluetoothOn()
	local result = self:setPowered(true)

	if string.match(result, "true") ~= nil then
		self:popup(_("Bluetooth turned on."))
		self:popup(_("Result: ") .. result)
	else
		self:popup(_("Result: ") .. result)
	end
end

function Bluetooth:onBluetoothOff()
	self:setPowered(false)
	self:popup(_("Bluetooth turned off."))
end

function Bluetooth:onBluetoothToggle()
	if self:isBluetoothOn() then
		self:onBluetoothOff()
	else
		self:onBluetoothOn()
	end
end

function Bluetooth:isBluetoothOn()
	local result = self:getProperty(self.adapter_path, "org.bluez.Adapter1", "Powered")
	return string.match(result, "true") ~= nil
end

function Bluetooth:onRefreshPairing()
	if not self:isBluetoothOn() then
		self:popup(_("Bluetooth is off. Please turn it on before refreshing pairing."))
		return
	end

	local status, err = pcall(function()
		-- Ensure the device path is valid
		if not self.input_device_path or self.input_device_path == "" then
			error("Invalid device path")
		end

		Device.input.close(self.input_device_path) -- Close the input using the high-level parameter
		Device.input.open(self.input_device_path) -- Reopen the input using the high-level parameter
		self:popup(_("Bluetooth device at ") .. self.input_device_path .. " is now open.")
	end)

	if not status then
		self:popup(_("Error: ") .. err)
	end
end

function Bluetooth:onConnectToDevice()
	if not self:isBluetoothOn() then
		self:popup(_("Bluetooth is off. Please turn it on before connecting to a device."))
		return
	end

	local device_path = "/org/bluez/hci0/dev_E4_17_D8_57_48_C5"

	local is_trusted = string.match(self:getProperty(device_path, "org.bluez.Device1", "Trusted"), "true") ~= nil
	local is_paired = string.match(self:getProperty(device_path, "org.bluez.Device1", "Paired"), "true") ~= nil

	if not is_trusted then
		local result_trust = self:setTrusted(device_path, true)
		logger.warn("bluetooth trust:", result_trust)
	end

	if not is_paired then
		local result_pairing = self:pair(device_path)
		logger.warn("bluetooth pairing:", result_pairing)
	end

	local result_connect = self:connect(device_path)
	logger.warn("bluetooth connect:", result_connect)

	local is_connected = string.match(self:getProperty(device_path, "org.bluez.Device1", "Connected"), "true") ~= nil

	local device_name = self:getProperty(device_path, "org.bluez.Device1", "Name")

	if is_connected and device_name then
		self:popup(_("Connection successful: ") .. device_name)
	else
		self:popup(_("Result: ") .. result_connect) -- Show full result for debugging if something goes wrong
	end
end

function Bluetooth:debugPopup(msg)
	self:popup(_("DEBUG: ") .. msg)
end

function Bluetooth:popup(text)
	local popup = InfoMessage:new({
		text = text,
	})
	UIManager:show(popup)
end

function Bluetooth:isWifiEnabled()
	local handle = io.popen("iwconfig")
	local result = handle:read("*a")
	handle:close()

	-- Check if Wi-Fi is enabled by looking for 'ESSID'
	return result:match("ESSID") ~= nil
end

function Bluetooth:run_dbus_command(command)
	local handle = io.popen(command .. " 2>&1")
	local result = handle:read("*a")
	handle:close()

	logger.warn("bluetooth result", result)
	return result
end

function Bluetooth:create_dbus_command(dest, device_path, interface, method, args)
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

-- Discover devices
function Bluetooth:startDiscovery()
	local command = self:create_dbus_command(self.dbus_dest, self.adapter_path, "org.bluez.Adapter1", "StartDiscovery")
	return self:run_dbus_command(command)
end

function Bluetooth:stopDiscovery()
	local command = self:create_dbus_command(self.dbus_dest, self.adapter_path, "org.bluez.Adapter1", "StopDiscovery")
	return self:run_dbus_command(command)
end

-- Set device as trusted
function Bluetooth:setTrusted(device_path, value)
	return self:setProperty(device_path, "org.bluez.Device1", "Trusted", value)
end

-- Pair with a device
function Bluetooth:pair(device_path)
	local command = self:create_dbus_command(self.dbus_dest, device_path, "org.bluez.Device1", "Pair")
	return self:run_dbus_command(command)
end

-- Connect to a device
function Bluetooth:connect(device_path)
	local command = self:create_dbus_command(self.dbus_dest, device_path, "org.bluez.Device1", "Connect")
	return self:run_dbus_command(command)
end

-- Disconnect from a device
function Bluetooth:disconnect(device_path)
	local command = self:create_dbus_command(self.dbus_dest, device_path, "org.bluez.Device1", "Disconnect")
	return self:run_dbus_command(command)
end

-- Power on or off the adapter
function Bluetooth:setPowered(value)
	return self:setProperty(self.adapter_path, "org.bluez.Adapter1", "Powered", value)
end

-- Get device or adapter property (e.g., Powered, Connected, Paired, etc.)
function Bluetooth:getProperty(device_path, interface, property)
	local args = {
		"string:'" .. interface .. "'",
		"string:'" .. property .. "'",
	}
	local command =
		self:create_dbus_command(self.dbus_dest, device_path, "org.freedesktop.DBus.Properties", "Get", args)
	local output = self:run_dbus_command(command)
	local result = output:match("variant%s+(.+)")
	return result
end

-- Set device or adapter property
function Bluetooth:setProperty(device_path, interface, property, value)
	local args = {
		"string:'" .. interface .. "'",
		"string:'" .. property .. "'",
		"variant:boolean:" .. tostring(value),
	}
	local command =
		self:create_dbus_command(self.dbus_dest, device_path, "org.freedesktop.DBus.Properties", "Set", args)
	local output = self:run_dbus_command(command)
	local result = self:getProperty(device_path, interface, property)
	return result
end

return Bluetooth

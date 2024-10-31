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
local Event = require("ui/event")
local logger = require("logger")

local _ = require("gettext")

---@class Bluetooth
---@field name string
---@field input_device_path string
---@field event_map table
---@field manager BluetoothManager
local Bluetooth = InputContainer:extend({
	name = "Bluetooth",
	input_device_path = "/dev/input/event3", -- Device path TODO: automate
	event_map = nil, -- TODO: load settings from file
	last_connected_device = nil, -- TODO: auto reconnect to last device when bluetooth starts
	manager = nil, -- Bluetooth "backend", only dbus so far
})

function Bluetooth:init()
	self:onDispatcherRegisterActions()
	self.ui.menu:registerToMainMenu(self)

	self:registerKeyEvents()
	self:registerEventMap()

	self:registerManager()
end

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

function Bluetooth:registerEventMap()
	local additional_event_map = {
		[105] = "BTLeft", -- Left for Previous Page
		[106] = "BTRight", -- Right for Next Page
		[109] = "BTBluetoothOff", -- Page Down for Bluetooth Off
	}
	for key, value in pairs(additional_event_map) do
		Device.input.event_map[key] = value
	end
end

function Bluetooth:registerManager()
	self.manager = require("bluetoothmanagerdbus")
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
				end,
				callback = function(touchmenu_instance)
					self:onBluetoothToggle()
					touchmenu_instance:updateItems()
				end,
			},
			{
				text = _("Discovering"),
				keep_menu_open = true,
				checked_func = function()
					return self:isBluetoothOn() and self:isDiscoveryOn()
				end,
				callback = function(touchmenu_instance)
					self:onDiscoveryToggle()
					touchmenu_instance:updateItems()
				end,
			},
			{
				text = _("List devices"),
				keep_menu_open = true,
				enabled_func = function()
					return self:isBluetoothOn()
				end,
				callback = function()
					self:onListDevices()
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
				enabled_func = function()
					return self:isBluetoothOn()
				end,
				callback = function()
					self:onRefreshInput()
				end,
			},
		},
	}
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

function Bluetooth:onBluetoothOn()
	local result = self.manager:setBluetoothOn()

	if result then
		self:popup(_("Bluetooth turned on."))
	else
		self:popup(_("Result: ") .. result)
	end
end

function Bluetooth:onBluetoothOff()
	local result = self.manager:setBluetoothOff()
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
	return self.manager:isBluetoothOn()
end

function Bluetooth:onDiscoveryToggle()
	local result
	if self.manager:isDiscoveryOn() then
		result = self.manager:stopDiscovery()
	else
		result = self.manager:startDiscovery()
	end
end

function Bluetooth:isDiscoveryOn()
	return self.manager:isDiscoveryOn()
end

function Bluetooth:onRefreshInput()
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

---@param device BluetoothItem
function Bluetooth:onConnectToDevice(device)
	if not device then
		self:popup(_("Error: no BT device"))
		return
	end

	logger.warn("bluetooth connecting to:", device.name)
	logger.warn("bluetooth connecting with path:", device.path)

	local is_trusted = self.manager:isDeviceTrusted(device)
	local is_paired = self.manager:isDevicePaired(device)

	if not is_trusted then
		is_trusted = self.manager:setTrusted(device, true)
		device.trusted = is_trusted
		logger.warn("bluetooth trust:", is_trusted)
	end

	if not is_paired then
		local result_pairing = self.manager:pairDevice(device)
		is_paired = self.manager:isDevicePaired(device)
		device.paired = is_paired
		logger.warn("bluetooth pairing:", result_pairing)
		logger.warn("bluetooth pairing:", is_paired)
	end

	local result_connect = self.manager:connectDevice(device)
	logger.warn("bluetooth connect:", result_connect)

	local is_connected = self.manager:isDeviceConnected(device)
	device.connected = is_connected

	if is_connected then
		self:onRefreshInput()
		self:popup(_("Connection successful: ") .. device.name)
	else
		self:popup(_("Result: ") .. result_connect) -- Show full result for debugging if something goes wrong
	end
end

function Bluetooth:onDisconnectFromDevice(device)
	local result = self.manager:disconnectDevice(device)
	local is_connected = self.manager:isDeviceConnected(device)

	if not is_connected then
		self:popup(_("Deconnection successful: ") .. device.name)
	else
		self:popup(_("Result: ") .. result) -- Show full result for debugging if something goes wrong
	end
end

function Bluetooth:onRemoveDevice(device)
	local is_connected = self.manager:isDeviceConnected(device)
	if is_connected then
		self:onDisconnectFromDevice(device)
	end

	local result = self.manager:removeDevice(device)
end

function Bluetooth:onListDevices()
	local devices = self.manager:listDevices()
	for _, obj in ipairs(devices) do
		logger.dbg("Object Path:", obj.path)
		logger.dbg("Object Name:", obj.name)
		logger.dbg("Object Address:", obj.address)
		logger.dbg("Object Interface:", obj.interface)
	end

	UIManager:show(require("bluetoothwidget"):new({
		device_list = devices,
		connect_callback = function(device)
			logger.warn("connect_callback for:", device.name)
			self:onConnectToDevice(device)
		end,
		disconnect_callback = function(device)
			logger.warn("disconnect_callback for:", device.name)
			self:onDisconnectFromDevice(device)
		end,
		forget_callback = function(device)
			logger.warn("remove_callback for:", device.name)
			self:onRemoveDevice(device)
		end,
		refresh_list_callback = function()
			logger.warn("refresh_list_callback")
			return self.manager:listDevices()
		end,
	}))
end

return Bluetooth

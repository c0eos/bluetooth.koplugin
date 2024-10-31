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
	---@type BluetoothManager
	self.manager = require("bluetoothmanagerdbus"):new({})
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
			{
				text = _("Scanning..."),
				keep_menu_open = true,
				enabled_func = function()
					return self:isBluetoothOn()
				end,
				callback = function()
					self:onDiscoverDevices()
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

function Bluetooth:onConnectToDevice(device_path)
	if not device_path then
		device_path = "/org/bluez/hci0/dev_E4_17_D8_57_48_C5"
	end

	logger.warn("bluetooth connecting to:", device_path)

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

function Bluetooth:onDiscoverDevices()
	local is_discovering = string.match(
		self:getProperty(self.adapter_path, "org.bluez.Adapter1", "Discovering"),
		"true"
	) ~= nil
	logger.warn("bluetooth discovering:", is_discovering)

	local result_managed_objects = self:getManagedObjects()
	result_managed_objects = self:parseManagedObjects(result_managed_objects)
	for _, obj in ipairs(result_managed_objects) do
		logger.warn("Object Path:", obj.path)
		logger.warn("Object Name:", obj.Name)
		logger.warn("Object Address:", obj.Address)
		logger.warn("Object RSSI:", obj.RSSI)
	end
	-- logger.warn("bluetooth objects:", self:parseManagedObjects(result_managed_objects))
	UIManager:show(require("bluetoothwidget"):new({
		device_list = result_managed_objects,
		connect_callback = function(device_path)
			self:onConnectToDevice(device_path)
		end,
	}))

	local result_discovery
	if is_discovering then
		-- result_discovery = self:stopDiscovery()
	else
		result_discovery = self:startDiscovery()
	end

	logger.warn("bluetooth discovery:", result_discovery)
end

return Bluetooth

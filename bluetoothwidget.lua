local BD = require("ui/bidi")
local ListView = require("ui/widget/listview")
local bit = require("bit")
local Geom = require("ui/geometry")
local Font = require("ui/font")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local InputContainer = require("ui/widget/container/inputcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local OverlapGroup = require("ui/widget/overlapgroup")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local GestureRange = require("ui/gesturerange")
local TextWidget = require("ui/widget/textwidget")
local ImageWidget = require("ui/widget/imagewidget")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local _ = require("gettext")
local T = require("ffi/util").template

local Screen = Device.screen
local band = bit.band
local logger = require("logger")

---@class NetworkItem
---@field height number
---@field width number
---@field info table
---@field icon_size any
local NetworkItem = InputContainer:extend({
	dimen = nil,
	height = Screen:scaleBySize(44),
	icon_size = Screen:scaleBySize(32),
	width = nil,
	info = nil,
	background = Blitbuffer.COLOR_WHITE,
})

function NetworkItem:init()
	self.dimen = Geom:new({ x = 0, y = 0, w = self.width, h = self.height })
	if not self.info.name or self.info.name == "" then
		self.info.name = "[hidden]"
	end

	local bt_icon = "plugins/bluetooth.koplugin/bluetooth.svg"

	local status = ""
	if self.info.paired then
		status = status .. "P"
	end
	if self.info.trusted then
		status = status .. "T"
	end
	if self.info.connected then
		status = status .. "C"
	end

	local name
	if status ~= "" then
		name = status .. " | " .. self.info.name
	else
		name = self.info.name
	end

	local horizontal_space = HorizontalSpan:new({ width = Size.span.horizontal_default })
	self.content_container = OverlapGroup:new({
		dimen = self.dimen:copy(),
		LeftContainer:new({
			dimen = self.dimen:copy(),
			HorizontalGroup:new({
				horizontal_space,
				ImageWidget:new({
					file = bt_icon,
					width = self.icon_size,
					height = self.icon_size,
					alpha = true,
					is_icon = true,
				}),
				horizontal_space,
				TextWidget:new({
					text = name,
					face = Font:getFace("cfont"),
				}),
			}),
		}),
	})
	self.btn_disconnect = nil
	self.btn_edit_nw = nil
	if self.info.connected then
		self.btn_disconnect = FrameContainer:new({
			bordersize = 0,
			padding = 0,
			TextWidget:new({
				text = _("disconnect"),
				face = Font:getFace("cfont"),
			}),
		})

		table.insert(
			self.content_container,
			RightContainer:new({
				dimen = self.dimen:copy(),
				HorizontalGroup:new({
					self.btn_disconnect,
					horizontal_space,
				}),
			})
		)
		self.setting_ui:setConnectedItem(self)
	end

	self[1] = FrameContainer:new({
		padding = 0,
		margin = 0,
		background = self.background,
		bordersize = 0,
		width = self.width,
		self.content_container,
	})

	if Device:isTouchDevice() then
		self.ges_events.TapSelect = {
			GestureRange:new({
				ges = "tap",
				range = self.dimen,
			}),
		}
		self.ges_events.Hold = {
			GestureRange:new({
				ges = "hold",
				range = self.dimen,
			}),
		}
	end
end

function NetworkItem:refresh()
	self:init()
	UIManager:setDirty(self.setting_ui, function()
		return "ui", self.dimen
	end)
end

function NetworkItem:connect()
	local connected_item = self.setting_ui:getConnectedItem()
	if connected_item then
		connected_item:disconnect()
	end

	self.setting_ui.connect_callback(self.info)

	local text = "Connected to " .. self.info.name

	self:refresh()
	UIManager:show(InfoMessage:new({ text = text, timeout = 3 }))
end

function NetworkItem:disconnect()
	local info = InfoMessage:new({ text = _("Disconnecting…") })
	UIManager:show(info)
	UIManager:forceRePaint()

	self.setting_ui.disconnect_callback(self.info)

	UIManager:close(info)

	self:refresh()
end

function NetworkItem:forget()
	local info = InfoMessage:new({ text = _("Forgetting device") })
	UIManager:show(info)
	UIManager:forceRePaint()

	self.setting_ui.forget_callback(self.info)

	UIManager:close(info)

	self:refresh()
end

function NetworkItem:onTapSelect(arg, ges_ev)
	if self.btn_disconnect then
		-- noop if touch is not on disconnect button
		if ges_ev.pos:intersectWith(self.btn_disconnect.dimen) then
			self:disconnect()
		end
	else
		self:connect()
	end
	return true
end

function NetworkItem:onHold(arg, ges_ev)
	self:forget()
	return true
end

---@class MinimalPaginator
local MinimalPaginator = Widget:extend({
	width = nil,
	height = nil,
	progress = nil,
})

function MinimalPaginator:getSize()
	return Geom:new({ w = self.width, h = self.height })
end

function MinimalPaginator:paintTo(bb, x, y)
	self.dimen = self:getSize()
	self.dimen.x, self.dimen.y = x, y
	-- paint background
	bb:paintRoundedRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_LIGHT_GRAY)
	-- paint percentage infill
	bb:paintRect(x, y, math.ceil(self.dimen.w * self.progress), self.dimen.h, Blitbuffer.COLOR_DARK_GRAY)
end

function MinimalPaginator:setProgress(progress)
	self.progress = progress
end

---@class NetworkSetting
---@field width number
---@field height number
---@field device_list any[]
local NetworkSetting = InputContainer:extend({
	width = nil,
	height = nil,
	device_list = nil,
	connect_callback = nil,
	disconnect_callback = nil,
	forget_callback = nil,
})

function NetworkSetting:init()
	self.width = self.width or Screen:getWidth() - Screen:scaleBySize(50)
	self.width = math.min(self.width, Screen:scaleBySize(600))

	local gray_bg = Blitbuffer.COLOR_GRAY_E
	local items = {}

	for idx, device in ipairs(self.device_list) do
		local bg
		if band(idx, 1) == 0 then
			bg = gray_bg
		else
			bg = Blitbuffer.COLOR_WHITE
		end
		table.insert(
			items,
			NetworkItem:new({
				width = self.width,
				info = device,
				background = bg,
				setting_ui = self,
			})
		)
	end

	self.status_text = TextWidget:new({
		text = "",
		face = Font:getFace("ffont"),
	})
	self.page_text = TextWidget:new({
		text = "",
		face = Font:getFace("ffont"),
	})

	self.pagination = MinimalPaginator:new({
		width = self.width,
		height = Screen:scaleBySize(8),
		percentage = 0,
		progress = 0,
	})

	self.height = self.height or math.min(Screen:getHeight() * 3 / 4, Screen:scaleBySize(800))
	self.popup = FrameContainer:new({
		background = Blitbuffer.COLOR_WHITE,
		padding = 0,
		bordersize = Size.border.window,
		VerticalGroup:new({
			align = "left",
			self.pagination,
			ListView:new({
				padding = 0,
				items = items,
				width = self.width,
				height = self.height - self.pagination:getSize().h,
				page_update_cb = function(curr_page, total_pages)
					self.pagination:setProgress(curr_page / total_pages)
					-- self.page_text:setText(curr_page .. "/" .. total_pages)
					UIManager:setDirty(self, function()
						return "ui", self.popup.dimen
					end)
				end,
			}),
		}),
	})

	self[1] = CenterContainer:new({
		dimen = { w = Screen:getWidth(), h = Screen:getHeight() },
		self.popup,
	})

	if Device:isTouchDevice() then
		self.ges_events.TapClose = {
			GestureRange:new({
				ges = "tap",
				range = Geom:new({
					x = 0,
					y = 0,
					w = Screen:getWidth(),
					h = Screen:getHeight(),
				}),
			}),
		}
	end

	if not self.connect_callback then
		return
	end

	UIManager:nextTick(function()
		local connected_item = self:getConnectedItem()
		if connected_item ~= nil then
			UIManager:show(InfoMessage:new({
				text = T(_("Connected to network %1"), BD.wrap(connected_item.info.name)),
				timeout = 3,
			}))
			self.connect_callback()
		end
	end)
end

function NetworkSetting:setConnectedItem(item)
	self.connected_item = item
end

function NetworkSetting:getConnectedItem()
	return self.connected_item
end

function NetworkSetting:onTapClose(arg, ges_ev)
	if ges_ev.pos:notIntersectWith(self.popup.dimen) then
		UIManager:close(self)
		return true
	end
end

function NetworkSetting:onCloseWidget()
	UIManager:setDirty(nil, "ui", self.popup.dimen)
end

function NetworkSetting:onRefreshList()
	self.device_list = self.refresh_list_callback()

	UIManager:setDirty(self, function()
		return "ui", self.popup.dimen
	end)
end

return NetworkSetting

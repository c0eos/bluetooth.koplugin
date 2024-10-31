---@class BluetoothItem
---@field address string | nil
---@field connected boolean | nil
---@field name string | nil
---@field paired boolean | nil
---@field rssi string | nil
---@field trusted boolean | nil
---@field interface? string | nil
---@field path? string | nil
local BluetoothItem = {
	address = nil,
	connected = nil,
	name = nil,
	paired = nil,
	rssi = nil,
	trusted = nil,

	interface = nil,
	path = nil,
}

function BluetoothItem:new(data)
	for key, value in pairs(data) do
		self[key] = value
	end
end

return BluetoothItem

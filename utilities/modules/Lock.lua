local Lock = {List = {}}
function Lock:LockProperties (Instance, Properties)
	local InstanceList = self.List[Instance]
	if not InstanceList then
		InstanceList = {}
		self.List[Instance] = InstanceList
	end
	for Property, Value in pairs(Properties) do
		if InstanceList[Property] then
			InstanceList[Property].Connection:Disconnect()
			InstanceList[Property] = nil
		end
		Instance[Property] = Value
		local Connection = Instance:GetPropertyChangedSignal(Property):Connect(function()
			if Instance[Property] ~= Value then
				Instance[Property] = Value
			end
		end)
		InstanceList[Property] = {
			Value = Value,
			Connection = Connection
		}
	end
end
function Lock:UnlockProperties (Instance, Properties)
	local InstanceList = self.List[Instance]
	if not InstanceList then
		return
	end
	for _, Property in pairs(Properties) do
		local t = InstanceList[Property]
		t.Connection:Disconnect()
		InstanceList[Property] = nil
	end
end
function Lock:UnlockAllProperties (Instance)
	local InstanceList = self.List[Instance]
	for Property, t in pairs(InstanceList) do
		t.Connection:Disconnect()
		InstanceList[Property] = nil
	end
end
function Lock:ClearAllLockedProperties ()
	local List = self.List
	for _, InstanceList in pairs(List) do
		for Property, t in pairs(InstanceList) do
			t.Connection:Disconnect()
		end
	end
	table.clear(List)
end
function Lock:GetLockedProperties (Instance)
	local InstanceList = self.List[Instance]
	local Properties = {}
	for Property, t in pairs(InstanceList) do
		Properties[Property] = t.Value
	end
	return Properties
end
function Lock:RecreateWhenDestroyed (Instance)
	local Parent = Instance.Parent
	local t = {}
	t.Event = function ()
		local Properties = self:GetLockedProperties(Instance)
		local New = Instance:Clone()
		self:LockProperties(New, Properties)
		Instance:Destroy() -- Disconnects all events.
		Instance = New
		Instance.Parent = Parent
		t.Connect()
	end
	t.Connect = function ()
		Instance:GetPropertyChangedSignal("Parent"):Connect(function()
			if Instance.Parent ~= Parent then
				t.Event()
			end
		end)
	end
	t.Connect()
end
return Lock

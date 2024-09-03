--[[

	Ideas:
		
		Blue Front Couch
		
		Show names of held items.
		
		Inventory GUI / Furniture placement GUI / Building GUI
		
		Redstone / Wiring system.

		(*) Camera bobble
		local function IsFirstPerson()
			 return (head.CFrame.p - camera.CFrame.p).Magnitude < 1
		end
		Directional walking animation.

		Model Separation: When you remove a part in the middle of a model, split each side of the model into individual models.

		Touch Welding: When you pick up a model that is anchored, automatically weld all the touching parts in the model before unanchoring it.
		
		Lerp at a speed of distance.
		
		+ gets more transparent the further your cursor is from it.
		
]]


local CollectionService = game:GetService("CollectionService")
local isHeld_TAG = "isHeld"

local Base = workspace:FindFirstChild("Base")

if Base then
	CollectionService:AddTag(Base, "__BASE__")
end

local GrabRemote = Instance.new("RemoteEvent", owner.PlayerGui) -- Used to pick up an item.
GrabRemote.Name = "GrabRemote"

local CheckOwnerRemote = Instance.new("RemoteEvent", owner.PlayerGui)
CheckOwnerRemote.Name = "CheckOwnerRemote"

local GetServerScriptRemote = Instance.new("RemoteFunction", owner.PlayerGui)
GetServerScriptRemote.Name = "GetServerScriptRemote"
GetServerScriptRemote.OnServerInvoke = function () return script end

CheckOwnerRemote.OnServerEvent:Connect(function(_, Target)
	local NetworkOwner = Target:GetNetworkOwner()
	
	print(Target.Name .. "'s NetworkOwner is " .. (NetworkOwner ~= nil and NetworkOwner.Name or "Server"))
end)

local PreviousItem = nil
local PreviousNetworkOwners = {}
local PreviousProperties = {}

function CreateUID ()
	return tick() .. "|" .. math.random(100000000, 999999999)
end

local CanCollide = false
local Transparency = 0.25

GrabRemote.OnServerEvent:Connect(function(_, Item: Instance, BreakJoints: Boolean, TouchingParts: Array, ThrowForce: Number, ThrowDirection: Vector3)
	if Item then -- User is picking up Item.
		CollectionService:AddTag(Item, isHeld_TAG)
		
		PreviousItem = Item
		
		if Item:IsA("BasePart") then
			if BreakJoints then
				Item.CanCollide = true
				
				Item:BreakJoints()
				Item.Parent = workspace
			end
			
			PreviousProperties[Item.Name] = {
				Item.CanCollide,
				Item.Transparency,
				Item.Massless
			}
			
			if Item.Anchored then Item.Anchored = false end
			if Item.CanCollide ~= CanCollide then Item.CanCollide = CanCollide end
			if Item.Transparency < Transparency then Item.Transparency = Transparency end
			if not Item.Massless then Item.Massless = true end
			
			PreviousNetworkOwners[Item.Name] = Item:GetNetworkOwner()
			Item:SetNetworkOwner(owner)
		elseif Item:IsA("Model") then
			local Parts = {}
			
			for _, Part in pairs(Item:GetDescendants()) do
				if Part:IsA("BasePart") then table.insert(Parts, Part)
					-- Store Part properties in PreviousProperties
					local UID = CreateUID()
					CollectionService:AddTag(Part, UID)
					
					PreviousProperties[UID] = {
						Part.CanCollide,
						Part.Transparency,
						Part.Massless
					}
					
					if Part.Anchored then Part.Anchored = false end
					if Part.CanCollide ~= CanCollide then Part.CanCollide = CanCollide end
					if Part.Transparency < Transparency then Part.Transparency = Transparency end
					if not Part.Massless then Part.Massless = true end
				elseif Part:IsA("Humanoid") then
					Part.Sit = true
				end
			end
			
			for _, Part in pairs(Parts) do -- Store original NetworkOwners.
				local NetworkOwner = Part:GetNetworkOwner()
				local UID = CreateUID()
				CollectionService:AddTag(Part, UID)
				
				if NetworkOwner then
					PreviousNetworkOwners[UID] = NetworkOwner
				else
					PreviousNetworkOwners[UID] = "Server"
				end
			end
			
			for _, Part in pairs(Parts) do -- Set NetworkOwner to the user.
				Part:SetNetworkOwner(owner)
			end
		end
	else
		if PreviousItem then -- User is dropping PreviousItem.
			if PreviousItem:IsA("BasePart") then
				if PreviousNetworkOwners[PreviousItem.Name] then
					PreviousItem:SetNetworkOwner(PreviousNetworkOwners[PreviousItem.Name])
				end
				
				if PreviousProperties[PreviousItem.Name] then
					local Properties = PreviousProperties[PreviousItem.Name]
					
					PreviousItem.CanCollide = Properties[1]
					PreviousItem.Transparency = Properties[2]
					PreviousItem.Massless = Properties[3]
				end
				
				for _, TouchingPart in pairs(TouchingParts) do
					if CollectionService:HasTag(TouchingPart, "__BASE__") then
						PreviousItem.Anchored = true
						
						table.remove(TouchingParts, table.find(TouchingParts, TouchingPart))
						
						break
					end
					
					local Weld = Instance.new("Weld", PreviousItem)
					Weld.C0 = PreviousItem.CFrame:Inverse() * TouchingPart.CFrame
					Weld.Part0 = PreviousItem
					Weld.Part1 = TouchingPart
				end
				
				if #TouchingParts == 1 then
					local Model = TouchingParts[1]:FindFirstAncestorOfClass("Model") or Instance.new("Model", TouchingParts[1].Parent)
					
					TouchingParts[1].Parent = Model
					PreviousItem.Parent = Model
				elseif #TouchingParts == 2 then
					
				end
			elseif PreviousItem:IsA("Model") then
				for _, Part in pairs(PreviousItem:GetDescendants()) do
					if Part:IsA("BasePart") or Part:IsA("Part") then
						local Tags = CollectionService:GetTags(Part)
						
						if Tags then
							for _, Tag in pairs(Tags) do
								if PreviousNetworkOwners[Tag] then
									if typeof(PreviousNetworkOwners[Tag]) == "string" then
										if PreviousNetworkOwners[Tag] == "Server" then
											Part:SetNetworkOwner(nil)
										end
									else
										Part:SetNetworkOwner(PreviousNetworkOwners[Tag])
									end
									
									CollectionService:RemoveTag(Part, Tag)
								end
								
								if PreviousProperties[Tag] then
									local Properties = PreviousProperties[Tag]
									
									Part.CanCollide = Properties[1]
									Part.Transparency = Properties[2]
									Part.Massless = Properties[3]
									
									CollectionService:RemoveTag(Part, Tag)
								end
							end
						end
					end
				end
			end
			
			table.clear(PreviousNetworkOwners)
			table.clear(PreviousProperties)
			
			CollectionService:RemoveTag(PreviousItem, isHeld_TAG)
		end
	end
end)

NLS([[
local GUI = {}
local FUNCTIONS = {}


-- Services
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")


local Camera = workspace.CurrentCamera
local PlayerGui = owner.PlayerGui
local Mouse = owner:GetMouse()


-- Remotes
local GrabRemote = PlayerGui:WaitForChild("GrabRemote") -- Used to pick up an item.
local CheckOwnerRemote = PlayerGui:WaitForChild("CheckOwnerRemote") -- Used to check the NetworkOwner of Mouse.Target
local GetServerScriptRemote = PlayerGui:WaitForChild("GetServerScriptRemote")

local ServerScript = GetServerScriptRemote:InvokeServer()


-- // Logical Variables ============================================================================================================== \\
-- 		Target Variables
local HOLDING = false -- True when the user is holding an item.																	(BOOLEAN)
local CURRENTITEM = nil -- Part or Model that is currently being held. 															(INSTANCE)
local TARGET = nil -- Current target being interacted with. (can be a Model or a Part) 											(INSTANCE)
local FIRSTINPUTTARGET = nil -- The first TARGET detected when the E key is pressed. 											(INSTANCE)
local MUSTBEUNLOCKED = false -- If true, you can only pick up unlocked items.													(BOOLEAN)
local MUSTBEINRANGE = true -- If true, you can only pick up items less than MAXGRABDISTANCE away.								(BOOLEAN)
local TOUCHINGPARTS = {} -- The parts of CURRENTITEM and the parts they're in contact with.										(ARRAY)
local CANBEPLACED = true -- False when the held item is in contact with parts that the item cannot be placed in.				(BOOLEAN)
local DROPPING = false -- True when the user is in the process of dropping something.											(BOOLEAN)

local ISHELD_TAG = "isHeld" -- The CollectionService tag applied to items when they're picked up.								(STRING)

local FilterDescendantsInstances = {owner.Character} -- The instances that the hold distance raycast ignores.					(ARRAY)
local RAYCASTPARAMS = RaycastParams.new() --																					(RAYCASTPARAMS)
RAYCASTPARAMS.FilterType = Enum.RaycastFilterType.Blacklist

FUNCTIONS.ReturnPrimaryPart = nil -- Used to get the PrimaryPart of a Model.													(FUNCTION)
FUNCTIONS.UpdateTarget = nil -- Updates the TARGET variable.																	(FUNCTION)
FUNCTIONS.UpdateRaycastHoldDistance = nil --																					(FUNCTION)
FUNCTIONS.FitsCriteria = nil --																									(FUNCTION)
FUNCTIONS.EditFilterDescendantsInstances = nil --																				(FUNCTION)
FUNCTIONS.ParentBodyMovers = nil --																								(FUNCTION)

-- 		Event Functions
FUNCTIONS.ON_PICKUP = nil -- The function run when an item is picked up.														(FUNCTION)
FUNCTIONS.HOLDING = nil -- The function run while an item is being held.														(FUNCTION)
FUNCTIONS.ON_DROP = nil -- The function run when an item is dropped.															(FUNCTION)

-- 		Item Manipulation Variables
local RAYCASTHOLDDISTANCE = 0 -- The max distance an object can be held from the user without clipping into objects.			(NUMBER)
local MAXGRABDISTANCE = 30 -- The max distance away from which an item can be picked up. 										(NUMBER)
local HOLDDISTANCE = 5 -- The distance the item is away from the user when they are holding it. 								(NUMBER)
local HOLDDISTANCEINCREMENT = 0.5 -- The increment at which the HOLDDISTANCE increases and decreases. 							(NUMBER)
local MAXHOLDDISTANCE = 25 -- The furthest CURRENTITEM can be held from the user. 												(NUMBER)
local MINIMUMHOLDDISTANCE = 0 -- The closest CURRENTITEM can be held to the user. 												(NUMBER)
local ROTATIONINCREMENT15 = math.rad(15) --																						(NUMBER)
local ROTATIONINCREMENT45 = math.rad(45) --																						(NUMBER)
local ROTATIONINCREMENT90 = math.rad(90) --																						(NUMBER)
local AXIS = "Y" -- The orientation axis being edited. 																			(STRING)
local ORIENTATION = CFrame.new() -- The orientation of the item being held. 													(ARRAY)
local ORIENTATIONINCREMENT = ROTATIONINCREMENT45 -- The increment that the Orientation value increases at. 						(NUMBER)
local THROWFORCE = 0 -- The force in velocity used to throw the item.															(NUMBER)
local THROWFORCEINCREASE = 5 -- The amount that THROWFORCE increases by.														(NUMBER)
local MAXTHROWFORCE = 75 -- The max force that can be used to throw the item.													(NUMBER)
local MODES = { --																												(ARRAY)
	["Camera"] = nil, --																										(FUNCTION)
	["Mouse"] = nil --																											(FUNCTION)
}
local MODE = "Camera"

MODES.Camera = function ()
	local Origin = Camera.CFrame.Position
	local Direction = Camera.CFrame.LookVector
	local Distance = math.clamp(HOLDDISTANCE, MINIMUMHOLDDISTANCE, (RAYCASTHOLDDISTANCE < MINIMUMHOLDDISTANCE and MINIMUMHOLDDISTANCE or RAYCASTHOLDDISTANCE))
	
	return Origin + Direction * Distance
end
MODES.Mouse = function ()
	local MouseLocation = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local ScreenRay = Camera:ScreenPointToRay(MouseLocation.X, MouseLocation.Y)
	
	local Origin = Camera.CFrame.Position
	local Direction = ScreenRay.Direction * 1e5
	
	local Result = workspace:Raycast(Origin, Direction, RAYCASTPARAMS)
	
	local HalfSize = CURRENTITEM.Size / 2
	
	local RotatedHalfSize = Vector3.new(
        math.abs(ORIENTATION.RightVector.X * HalfSize.X) + math.abs(ORIENTATION.UpVector.X * HalfSize.Y) + math.abs(ORIENTATION.LookVector.X * HalfSize.Z),
        math.abs(ORIENTATION.RightVector.Y * HalfSize.X) + math.abs(ORIENTATION.UpVector.Y * HalfSize.Y) + math.abs(ORIENTATION.LookVector.Y * HalfSize.Z),
        math.abs(ORIENTATION.RightVector.Z * HalfSize.X) + math.abs(ORIENTATION.UpVector.Z * HalfSize.Y) + math.abs(ORIENTATION.LookVector.Z * HalfSize.Z)
    )
	
	local Destination = Result ~= nil and Result.Position + Result.Normal * RotatedHalfSize or Origin + Direction
	
	return Destination
end

--		Input Variables
local PICKUP_INPUT = Enum.KeyCode.E --																							(ENUM)
local ROTATE_INPUT = Enum.KeyCode.R --																							(ENUM)
local INCREASEDISTANCE_INPUT = Enum.KeyCode.Five --																				(ENUM)
local DECREASEDISTANCE_INPUT = Enum.KeyCode.Four --																				(ENUM)
local CHECK_NETWORKOWNER_INPUT = Enum.KeyCode.Z --																				(ENUM)
local CHANGE_CAMERAMODE_INPUT = Enum.KeyCode.C --																				(ENUM)
local CHANGE_MODE = Enum.KeyCode.Q --																							(ENUM)
local PICKUPINPUTDOWN = false -- True when the E key is pressed. 																(BOOLEAN)
local CTRLDOWN = false -- True when the left control button is held down. 														(BOOLEAN)
local SHIFTDOWN = false -- True when the left shift button is held down. 														(BOOLEAN)
local ALTDOWN = false -- True when the left alt button is held down.															(BOOLEAN)
local PICKUP_INPUTOBJECT = {UserInputType = Enum.UserInputType.Keyboard, KeyCode = PICKUP_INPUT} --								(ARRAY)

-- 		GUI Variables
local EHOLD = 0.5 -- The amount of time in seconds it takes GUI.Progress.Value to reach 360. 									(NUMBER)
local ETWEEN = nil -- The tween used to lerp the GUI.PROGRESS value. Updates with a new Tween on every E InputBegan. 			(INSTANCE)
local CARETSPEED = 0.45 -- The speed GUI.GrabCaret lerps at. 																	(NUMBER)

--		Audios
local ScrollWheelClickSound = Instance.new("Sound", owner.PlayerGui) --															(SOUND)
ScrollWheelClickSound.Name = "ScrollWheelClick"
ScrollWheelClickSound.SoundId = "rbxassetid://9121005567"
ScrollWheelClickSound.PlaybackSpeed = 1
ScrollWheelClickSound.Volume = 2.25

local RotateSound = Instance.new("Sound", owner.PlayerGui) --																	(SOUND)
RotateSound.Name = "Rotate"
RotateSound.SoundId = "rbxassetid://9114067301"
RotateSound.PlaybackSpeed = 1.5
RotateSound.Volume = 0.75

local HighlightColorWhite = {
	FillColor = Color3.fromRGB(100, 100, 100),
	OutlineColor = Color3.fromRGB(255, 255, 255)
}
local HighlightColorRed = {
	FillColor = Color3.fromRGB(255, 0, 0),
	OutlineColor = Color3.fromRGB(200, 0, 0)
}

-- \\ =============================================================================================================================== //

local Highlight = Instance.new("Highlight", ServerScript)
Highlight.FillTransparency = 0.8
Highlight.OutlineTransparency = 0.25
Highlight.FillColor = HighlightColorWhite.FillColor
Highlight.OutlineColor = HighlightColorWhite.OutlineColor

local SelectionBox = Instance.new("SelectionBox", owner.Character)
SelectionBox.LineThickness = 0.01
SelectionBox.Transparency = 0.75
SelectionBox.Color3 = Color3.fromRGB(0, 200, 0)
SelectionBox.Transparency = 0.5

local Attachment0 = Instance.new("Attachment")
local AlignPosition = Instance.new("AlignPosition")
local AlignOrientation = Instance.new("AlignOrientation")

AlignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
AlignPosition.Attachment0 = Attachment0
AlignPosition.RigidityEnabled = true
AlignPosition.MaxForce = Vector3.one * math.huge
AlignPosition.Responsiveness = Vector3.one * math.huge

AlignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
AlignOrientation.Attachment0 = Attachment0
AlignOrientation.RigidityEnabled = true
AlignOrientation.MaxTorque = Vector3.one * math.huge
AlignOrientation.Responsiveness = Vector3.one * math.huge

FUNCTIONS.ParentBodyMovers = function (Parent)
	Attachment0.Parent = Parent
	AlignPosition.Parent = Parent
	AlignOrientation.Parent = Parent
end

FUNCTIONS.EditFilterDescendantsInstances = function (add, ...)
	for _, v in pairs({...}) do
		if add then
			table.insert(FilterDescendantsInstances, v)
		else
			table.remove(FilterDescendantsInstances, table.find(FilterDescendantsInstances, v))
		end
	end
	
	RAYCASTPARAMS.FilterDescendantsInstances = FilterDescendantsInstances
end

FUNCTIONS.ReturnPrimaryPart = function (Model)
	return Model:FindFirstChild("HumanoidRootPart") or Model.PrimaryPart or Model:FindFirstChildOfClass("BasePart", true) or Model:FindFirstChildOfClass("Part", true)
end

FUNCTIONS.FitsCriteria = function (Item) -- Check if an item fits the criteria for being picked up.
	if Item:IsA("BasePart") then
		if MUSTBEUNLOCKED and Item.Locked then return end
		if MUSTBEINRANGE and (Item.Position - owner.Character.Head.Position).Magnitude > MAXGRABDISTANCE then return end
		if CollectionService:HasTag(Item, ISHELD_TAG) then return end
	elseif Item:IsA("Model") then
		if MUSTBEUNLOCKED then for _, BasePart in pairs(Item:GetDescendants()) do if BasePart:IsA("BasePart") then if BasePart.Locked then return end end end end
		if MUSTBEINRANGE and (FUNCTIONS.ReturnPrimaryPart(Item).Position - owner.Character.Head.Position).Magnitude > MAXGRABDISTANCE then return end
		if CollectionService:HasTag(Item, ISHELD_TAG) then return end
	else
		return
	end
	
	return Item
end

FUNCTIONS.UpdateTarget = function () -- Sets TARGET to the suitable Part or Model of Mouse.Target depending on TARGET and INPUT based factors.
	if not HOLDING then
		local MouseTarget = Mouse.Target
		
		if MouseTarget then
			TARGET = FUNCTIONS.FitsCriteria(ALTDOWN and MouseTarget or (MouseTarget:FindFirstAncestorOfClass("Model") or MouseTarget))
		else
			TARGET = nil
		end
	end
end

FUNCTIONS.UpdateRaycastHoldDistance = function ()
	local RaycastResult = workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * MAXHOLDDISTANCE, RAYCASTPARAMS)
	
	if RaycastResult then
		RAYCASTHOLDDISTANCE = (RaycastResult.Position - Camera.CFrame.Position).Magnitude
	else
		RAYCASTHOLDDISTANCE = MAXHOLDDISTANCE
	end
end


-- // GUI and Handling ======================================================================================================= \\
-- Functions
GUI.InputBegan = nil
GUI.InputChanged = nil
GUI.InputEnded = nil
GUI.UpdateProgressBar = nil
GUI.UpdateGrabCaret = nil

local GrabCaretSize = Camera.ViewportSize.Y * 0.025
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() GrabCaretSize = Camera.ViewportSize.Y * 0.025 GUI.GrabCaret.Size = UDim2.fromOffset(GrabCaretSize, GrabCaretSize) end)

GUI.UpdateProgressBar = function () -- Uses the PROGRESS value in the GUI table.
	local Value = (GUI.PROGRESS.Value % 360 + 360) % 360

	GUI.RightBar.Rotation = math.clamp(Value - 180, -180, 0)
	
	if Value > 180 then
		GUI.LeftBar.Visible = true
		GUI.LeftBar.Rotation = math.clamp(Value - 360, -180, 0)
	else
		GUI.LeftBar.Visible = false
	end
end

GUI.UpdateGrabCaret = function (Position, InBounds)
	if InBounds then
		GUI.GrabCaret.Position = GUI.GrabCaret.Position:Lerp(UDim2.new(0, Position.X, 0, Position.Y), CARETSPEED)
	else
		GUI.GrabCaret.Position = GUI.GrabCaret.Position:Lerp(UDim2.new(0.5, 0, 0.5, 0), CARETSPEED)
	end
end

GUI.CircularProgressBarScreenGui = Instance.new("ScreenGui")
GUI.CircularProgressBar = Instance.new("Frame")
GUI.LeftBack = Instance.new("ImageLabel")
GUI.LeftBar = Instance.new("Frame")
GUI.LeftBarImage = Instance.new("ImageLabel")
GUI.RightBack = Instance.new("ImageLabel")
GUI.RightBar = Instance.new("Frame")
GUI.RightBarImage = Instance.new("ImageLabel")
GUI.GrabCaret = Instance.new("TextLabel")
GUI.PROGRESS = Instance.new("NumberValue")
GUI.PROGRESSBARBACKCOLOR = Color3.new(0, 0, 0)
GUI.PROGRESSBARIMAGECOLOR = Color3.new(150, 150, 150)
-- \\ ======================================================================================================================== //

-- // Serialized GUI ========================================================= \\
GUI.CircularProgressBarScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
GUI.CircularProgressBarScreenGui.Name = "CircularProgressBarScreenGui"
GUI.CircularProgressBarScreenGui.IgnoreGuiInset = true
GUI.CircularProgressBarScreenGui.Parent = owner.PlayerGui

GUI.GrabCaret.AnchorPoint = Vector2.new(0.5, 0.5)
GUI.GrabCaret.Size = UDim2.fromOffset(GrabCaretSize, GrabCaretSize)
GUI.GrabCaret.Position = UDim2.new(0.5, 0, 0.5, 0)
GUI.GrabCaret.BackgroundTransparency = 1
GUI.GrabCaret.BorderColor3 = Color3.new(150, 150, 150)
GUI.GrabCaret.TextStrokeTransparency = 0
GUI.GrabCaret.TextStrokeColor3 = Color3.new(0, 0, 0)
GUI.GrabCaret.TextColor3 = Color3.new(255, 255, 255)
GUI.GrabCaret.TextScaled = true
GUI.GrabCaret.Text = "+"
GUI.GrabCaret.Name = "GrabCaret"
GUI.GrabCaret.Parent = GUI.CircularProgressBarScreenGui

GUI.CircularProgressBar.AnchorPoint = Vector2.new(0.5, 0.5)
GUI.CircularProgressBar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
GUI.CircularProgressBar.BackgroundTransparency = 1
GUI.CircularProgressBar.Position = UDim2.new(0.5, 0, 0.5, 0)
GUI.CircularProgressBar.Size = UDim2.new(2.5, 0, 2.5, 0)
GUI.CircularProgressBar.Rotation = 180
GUI.CircularProgressBar.Visible = false
GUI.CircularProgressBar.Name = "CircularProgressBar"
GUI.CircularProgressBar.Parent = GUI.GrabCaret

GUI.LeftBack.Image = "rbxassetid://2094637131"
GUI.LeftBack.ImageColor3 = GUI.PROGRESSBARBACKCOLOR
GUI.LeftBack.ImageRectSize = Vector2.new(128, 256)
GUI.LeftBack.SliceCenter = Rect.new(0, 0, 128, 256)
GUI.LeftBack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GUI.LeftBack.BackgroundTransparency = 1
GUI.LeftBack.Size = UDim2.new(0.5, 0, 1, 0)
GUI.LeftBack.ZIndex = 2
GUI.LeftBack.Name = "LeftBack"
GUI.LeftBack.Parent = GUI.CircularProgressBar

GUI.LeftBar.AnchorPoint = Vector2.new(0.5, 0.5)
GUI.LeftBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GUI.LeftBar.BackgroundTransparency = 1
GUI.LeftBar.Position = UDim2.new(1, 0, 0.5, 0)
GUI.LeftBar.Size = UDim2.new(2, 0, 1, 0)
GUI.LeftBar.Name = "LeftBar"
GUI.LeftBar.Parent = GUI.LeftBack

GUI.LeftBarImage.Image = "rbxassetid://2094676785"
GUI.LeftBarImage.ImageColor3 = GUI.PROGRESSBARIMAGECOLOR
GUI.LeftBarImage.ImageRectSize = Vector2.new(128, 256)
GUI.LeftBarImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GUI.LeftBarImage.BackgroundTransparency = 1
GUI.LeftBarImage.Size = UDim2.new(0.5, 0, 1, 0)
GUI.LeftBarImage.Name = "LeftBarImage"
GUI.LeftBarImage.Parent = GUI.LeftBar

GUI.RightBack.Image = "rbxassetid://2094637131"
GUI.RightBack.ImageColor3 = GUI.PROGRESSBARBACKCOLOR
GUI.RightBack.ImageRectOffset = Vector2.new(128, 0)
GUI.RightBack.ImageRectSize = Vector2.new(128, 256)
GUI.RightBack.SliceCenter = Rect.new(0, 0, 128, 256)
GUI.RightBack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GUI.RightBack.BackgroundTransparency = 1
GUI.RightBack.Position = UDim2.new(0.5, 0, 0, 0)
GUI.RightBack.Size = UDim2.new(0.5, 0, 1, 0)
GUI.RightBack.Name = "RightBack"
GUI.RightBack.Parent = GUI.CircularProgressBar

GUI.RightBar.AnchorPoint = Vector2.new(0.5, 0.5)
GUI.RightBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GUI.RightBar.BackgroundTransparency = 1
GUI.RightBar.Position = UDim2.new(0, 0, 0.5, 0)
GUI.RightBar.Size = UDim2.new(2, 0, 1, 0)
GUI.RightBar.Name = "RightBar"
GUI.RightBar.Parent = GUI.RightBack

GUI.RightBarImage.Image = "rbxassetid://2094676785"
GUI.RightBarImage.ImageColor3 = GUI.PROGRESSBARIMAGECOLOR
GUI.RightBarImage.ImageRectOffset = Vector2.new(128, 0)
GUI.RightBarImage.ImageRectSize = Vector2.new(128, 256)
GUI.RightBarImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
GUI.RightBarImage.BackgroundTransparency = 1
GUI.RightBarImage.Position = UDim2.new(0.5, 0, 0, 0)
GUI.RightBarImage.Size = UDim2.new(0.5, 0, 1, 0)
GUI.RightBarImage.Name = "RightBarImage"
GUI.RightBarImage.Parent = GUI.RightBar

GUI.PROGRESS:GetPropertyChangedSignal("Value"):Connect(GUI.UpdateProgressBar)
GUI.PROGRESS.Value = 0 -- Doesn't trigger the changed signal because NumberValues are already at 0.
GUI.UpdateProgressBar() -- Ensure that the progress has been updated to 0.
-- \\ ======================================================================== //


-- // Event Functions \\
FUNCTIONS.ON_PICKUP = function ()
	CURRENTITEM = TARGET
	FUNCTIONS.EditFilterDescendantsInstances(true, CURRENTITEM)
	
	GrabRemote:FireServer(CURRENTITEM, ALTDOWN)
	
	repeat task.wait() until CollectionService:HasTag(CURRENTITEM, ISHELD_TAG)
	
	HOLDING = true
	
	if CURRENTITEM:IsA("BasePart") then
		FUNCTIONS.ParentBodyMovers(CURRENTITEM)
	elseif CURRENTITEM:IsA("Model") then
		FUNCTIONS.ParentBodyMovers(FUNCTIONS.ReturnPrimaryPart(CURRENTITEM))
	end
end

FUNCTIONS.HOLDING = function ()
	local Destination = MODES[MODE]()
	local NewCFrame = CFrame.new(Destination) * ORIENTATION
	
	local OldCFrame = CURRENTITEM:GetPivot()
	local Distance = (NewCFrame.Position - OldCFrame.Position).Magnitude
	
	NewCFrame = OldCFrame:Lerp(NewCFrame, math.clamp(Distance, 0.5, 1))
	
	CURRENTITEM:PivotTo(NewCFrame)
	
	AlignPosition.Position = NewCFrame.Position
	AlignOrientation.CFrame = NewCFrame
	
	if CURRENTITEM:IsA("BasePart") then
		local TouchingParts = workspace:GetPartsInPart(CURRENTITEM)
		
		for i, Part in pairs(TouchingParts) do
			if Part:IsDescendantOf(owner.Character) then
				--TouchingParts[i] = nil
			end
		end
		
		TOUCHINGPARTS = TouchingParts
		
		if #TOUCHINGPARTS > 0 then -- CURRENTITEM is colliding.
			SelectionBox.Adornee = CURRENTITEM
		else
			SelectionBox.Adornee = nil
		end
	elseif CURRENTITEM:IsA("Model") then
	end
end

FUNCTIONS.ON_DROP = function ()
	GrabRemote:FireServer(false, false, TOUCHINGPARTS)
	
	local startwait = tick()
	
	repeat task.wait() if tick() - startwait > 3 then warn("Was unable to drop " .. CURRENTITEM.Name .. ". It is now locked through CollectionService.") break end until not CollectionService:HasTag(CURRENTITEM, ISHELD_TAG)
	
	HOLDING = false
	
	SelectionBox.Adornee = nil
	Highlight.Adornee = nil
	
	FUNCTIONS.ParentBodyMovers(nil)
	FUNCTIONS.EditFilterDescendantsInstances(false, CURRENTITEM)
	
	if THROWFORCE > 0 then
		local Velocity = Camera.CFrame.LookVector * THROWFORCE
		
		print(Velocity)
		
		CURRENTITEM.AssemblyLinearVelocity = Camera.CFrame.LookVector * THROWFORCE
	end
	
	CURRENTITEM = nil
end


-- // Input Handling ============================================================================================ \\
GUI.InputBegan = function (Input, GPE)
	if not GPE then
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if Input.KeyCode == PICKUP_INPUT then
				PICKUPINPUTDOWN = true
				
				if CURRENTITEM then
					DROPPING = true
					
					local DROPSTART = tick()
					
					repeat
						if tick() - DROPSTART > 0.5 then
							THROWFORCE = math.clamp(THROWFORCE + THROWFORCEINCREASE, 0, MAXTHROWFORCE)
						end
						
						task.wait()
					until not DROPPING
				else
					if TARGET then
						FIRSTINPUTTARGET = TARGET
						GUI.CircularProgressBar.Visible = true
						ETWEEN = TweenService:Create(GUI.PROGRESS, TweenInfo.new(EHOLD, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {Value = 359.9})
						ETWEEN:Play()
					end
				end
			elseif Input.KeyCode == Enum.KeyCode.LeftControl then
				CTRLDOWN = true
			elseif Input.KeyCode == Enum.KeyCode.LeftShift then
				SHIFTDOWN = true
			elseif Input.KeyCode == Enum.KeyCode.LeftAlt then
				ALTDOWN = true
				
				Highlight.FillColor = HighlightColorRed.FillColor
				Highlight.OutlineColor = HighlightColorRed.OutlineColor
			elseif Input.KeyCode == INCREASEDISTANCE_INPUT and CURRENTITEM then
				HOLDDISTANCE = math.clamp(HOLDDISTANCE + HOLDDISTANCEINCREMENT, MINIMUMHOLDDISTANCE, MAXHOLDDISTANCE)
			elseif Input.KeyCode == DECREASEDISTANCE_INPUT and CURRENTITEM then
				HOLDDISTANCE = math.clamp(HOLDDISTANCE - HOLDDISTANCEINCREMENT, MINIMUMHOLDDISTANCE, MAXHOLDDISTANCE)
			elseif Input.KeyCode == CHECK_NETWORKOWNER_INPUT then
				CheckOwnerRemote:FireServer(Mouse.Target)
			elseif Input.KeyCode == Enum.KeyCode.One then
				AXIS = "X"
			elseif Input.KeyCode == Enum.KeyCode.Two then
				AXIS = "Y"
			elseif Input.KeyCode == Enum.KeyCode.Three then
				AXIS = "Z"
			elseif Input.KeyCode == ROTATE_INPUT then
				RotateSound:Play()
				if SHIFTDOWN and CTRLDOWN then
					ORIENTATION = CFrame.new()
					return
				end
				
				if AXIS == "X" then
					ORIENTATION = ORIENTATION * CFrame.Angles(ORIENTATIONINCREMENT, 0, 0)
				elseif AXIS == "Y" then
					ORIENTATION = ORIENTATION * CFrame.Angles(0, ORIENTATIONINCREMENT, 0)
				elseif AXIS == "Z" then
					ORIENTATION = ORIENTATION * CFrame.Angles(0, 0, ORIENTATIONINCREMENT)
				end
			elseif Input.KeyCode == CHANGE_CAMERAMODE_INPUT then
				if not CTRLDOWN then
					if owner.CameraMode == Enum.CameraMode.Classic then
						owner.CameraMode = Enum.CameraMode.LockFirstPerson
					elseif owner.CameraMode == Enum.CameraMode.LockFirstPerson then
						owner.CameraMode = Enum.CameraMode.Classic
					end
				else
				end
			elseif Input.KeyCode == CHANGE_MODE then
				if MODE == "Camera" then
					MODE = "Mouse"
				elseif MODE == "Mouse" then
					MODE = "Camera"
				end
			end
		end
	end
end

GUI.InputChanged = function (Input, GPE)
	if not GPE then
		if Input.UserInputType == Enum.UserInputType.MouseWheel then
			if CURRENTITEM then
				ScrollWheelClickSound:Play()
				
				if Input.Position.Z > 0 then -- Up
					HOLDDISTANCE = math.clamp(HOLDDISTANCE + HOLDDISTANCEINCREMENT, MINIMUMHOLDDISTANCE, MAXHOLDDISTANCE)
				else -- Down
					HOLDDISTANCE = math.clamp(HOLDDISTANCE - HOLDDISTANCEINCREMENT, MINIMUMHOLDDISTANCE, MAXHOLDDISTANCE)
				end
			end
		end
	end
end

GUI.InputEnded = function (Input, GPE)
	if not GPE then
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			if Input.KeyCode == PICKUP_INPUT then
				if CURRENTITEM and DROPPING then
					
					-- //////////////////////////////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
					-- ||||||||||||||||||||||||||||||||| User is dropping CURRENTITEM. ||||||||||||||||||||||||||||||||||
					-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\///////////////////////////////////////////////
					
					FUNCTIONS.ON_DROP()
					DROPPING = false
					THROWFORCE = 0
					
				end
				
				PICKUPINPUTDOWN = false
				FIRSTINPUTTARGET = nil
				
				if ETWEEN then
					GUI.CircularProgressBar.Visible = false
					ETWEEN:Pause()
					ETWEEN = nil
					GUI.PROGRESS.Value = 0
				end
			elseif Input.KeyCode == Enum.KeyCode.LeftControl then
				CTRLDOWN = false
			elseif Input.KeyCode == Enum.KeyCode.LeftShift then
				SHIFTDOWN = false
			elseif Input.KeyCode == Enum.KeyCode.LeftAlt then
				ALTDOWN = false
				
				Highlight.FillColor = HighlightColorWhite.FillColor
				Highlight.OutlineColor = HighlightColorWhite.OutlineColor
			end
		end
	end
end

UserInputService.InputBegan:Connect(GUI.InputBegan)
UserInputService.InputChanged:Connect(GUI.InputChanged)
UserInputService.InputEnded:Connect(GUI.InputEnded)
-- \\ =========================================================================================================== //



-- // Main Loop \\
RunService.PostSimulation:Connect(function(Delta)
	-- Update the TARGET variable.
	FUNCTIONS.UpdateTarget()
	Highlight.Adornee = TARGET
	
	if HOLDING then
		FUNCTIONS.UpdateRaycastHoldDistance()
	end
	
	if SHIFTDOWN and not CTRLDOWN then
		ORIENTATIONINCREMENT = ROTATIONINCREMENT90
	elseif CTRLDOWN and not SHIFTDOWN then
		ORIENTATIONINCREMENT = ROTATIONINCREMENT15
	elseif not SHIFTDOWN and not CTRLDOWN then
		ORIENTATIONINCREMENT = ROTATIONINCREMENT45
	elseif SHIFTDOWN and CTRLDOWN then
		ORIENTATIONINCREMENT = ROTATIONINCREMENT45 -- not used.
	end
	
	-- Update GUI GrabCaret and CircularProgressBar.
	if CURRENTITEM and HOLDING then
		GUI.GrabCaret.Position = GUI.GrabCaret.Position:Lerp(UDim2.fromScale(0.5, 0.5), CARETSPEED)
		if GUI.CircularProgressBar.Visible then GUI.CircularProgressBar.Visible = false end
		
		
		-- /////////////////////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
		-- ||||||||||||||||||||||||||||| User is holding CURRENTITEM. |||||||||||||||||||||||||||||
		-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\///////////////////////////////////////////////
		
		FUNCTIONS.HOLDING()
		
	else
		if not GUI.GrabCaret.Visible then GUI.GrabCaret.Visible = true end
	
		if TARGET then
			local TargetPosition, InBounds = Camera:WorldToViewportPoint(TARGET:IsA("Model") and FUNCTIONS.ReturnPrimaryPart(TARGET).Position or TARGET.Position)
			GUI.UpdateGrabCaret(TargetPosition, InBounds)
		else
			GUI.UpdateGrabCaret(UDim2.fromScale(0.5, 0.5))
			
			if ETWEEN then ETWEEN:Pause() end
			GUI.PROGRESS.Value = 0
			if GUI.CircularProgressBar.Visible then GUI.CircularProgressBar.Visible = false end
		end
	end
	
	if PICKUPINPUTDOWN then
		if TARGET then
			if TARGET == FIRSTINPUTTARGET then
				if not CURRENTITEM then
					if GUI.PROGRESS.Value > 359 then
					
						-- ///////////////////////////////////////////////////////////////\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
						-- |||||||||||||||||||||| User is picking up TARGET. Despite being in a RunService loop, this only runs once. ||||||||||||||||||||||
						-- \\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\//////////////////////////////////////////////////////////////////
						
						FUNCTIONS.ON_PICKUP()
						
					end
				end
			else
				--GUI.InputEnded(PICKUP_INPUTOBJECT, false)
				-- what the hecking heck does this even do
			end
		end
	end
end)
]], owner.PlayerGui)

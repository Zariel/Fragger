local f = CreateFrame("Frame")
f:Hide()
local timer = 0

local jobList
local moveJob
local job
local queue = {}
local speed = 0

local itemWeights = {
	["Weapon"] = 13,
	["Armor"] = 12,
	["Consumable"] = 11,
	["Trade Goods"] = 10,
	["Glyph"] = 9,
	["Gem"] = 8,
	["Recipe"] = 7,
	["Goods"] = 6,
	["Container"] = 5,
	["Projectile"] = 4,
	["Quiver"] = 3,
	["Quest"] = 2,
	["Miscellaneous"] = 1,
	[0] = 0,
}

-- item class
local newItem = setmetatable({}, {
	__call = function(self, ...)
		local t =  setmetatable({}, { __index = self })
		t:__init(...)
		return t
	end
})

function newItem:__init(link)
	local name, quality, iLevel, reqLevel, class, subClass, maxStack = false, 0, false, false, 0, false, false

	if link then
		name, _, quality, iLevel, reqLevel, class, subClass, maxStack = GetItemInfo(link)
	end

	self.name = name
	self.quality = quality
	self.ilevel = ilevel
	self.level = level
	self.class = class
	self.subClass = subClass
	self.type = link and GetItemFamily(link)
end

-- Sorting
local subclassSort = function(a, b)
end

local classSort = function(a, b)
	if a and b then
		return itemWeights[a.class] > itemWeights[b.class]
	else
		return true
	end
end

local qualitySort = function(a, b)
	if a and b then
		if a.quality == b.quality then
			--return classSort(a, b)
			return false
		else
			return a.quality > b.quality
		end
	else
		return true
	end
	--	return a.quality > b.quality
end


local sort = function(a, b)
	return qualitySort(a, b)
end

-- Core

local itemInBag = function(item, bag)
	local itemFamily = GetItemFamily(item)
	local bagFamilty = GetItemFamily(bagFamily)
end

local getBags = function()
	local t = {}
	local i = 1
	local bags = {}
	local special = {}
	local reverse = {}

	for bag = 0, 4 do
		local slots = GetContainerNumSlots(bag)
		local type = select(2, GetContainerNumFreeSlots(bag))
		if slots > 0 then
			bags[bag] = slots
			reverse[bag] = {}
		end

		if type and type > 0 then
			special[bag] = { [0] = type }
		end

		for slot = 1, slots do
			local link = GetContainerItemLink(bag, slot)
			local item = newItem(link)

			item.bag = bag
			item.slot = slot
			item.empty = not link
			item.pos = i

			t[i] = item

			reverse[bag][slot] = i

			if type and type > 0 then
				special[bag][slot] = item
			end

			i = i + 1
		end
	end

	return t, bags, special, reverse
end

local getFirstEmpty = function(bags)
	for i = 1, #bags do
		if bags[i].empty then
			return i, bags[i]
		end
	end
end

local itemCount = function(bags)
	local count = 0
	for k, v in pairs(bags) do
		if v.name then
			count = count + 1
		end
	end
	return count
end

local defragMap = function()
	local bags, slot, special, reverse = getBags()
	local map = {}

	local specials = {}
	for k, v in pairs(special) do
		specials[v[0]] = k
	end

	-- Bottom up search to fill empty spaces
	local item
	for i = #bags, 1, -1 do
		item = bags[i]
		if item and item.name and not item.empty then
			if item.type and item.type > 0 and specials[item.type] then
				-- Madness :E
				for b, t in pairs(special) do
					-- Fits in the bag
					if bit.band(item.type, t[0]) > 0 then
						local k, v = getFirstEmpty(t)
						if k and k < item.slot or v.bag ~= item.bag then
							map[#map + 1] = { item.bag, item.slot, v.bag, v.slot }
							bags[reverse[v.bag][v.slot]].empty = false
							break
						end
					end
				end
			else
				local k, v = getFirstEmpty(bags)
				if k and k < i then
					--Lets check if it can go in the bag
					-- Is special!

					--Move item -> v
					map[#map + 1] = { item.bag, item.slot, v.bag, v.slot }
					bags[k].empty = false
				else
					--break
				end
			end
		end
	end

	return map
end

local sortMap = function()
	local bags, slots, special = getBags()
	local map = {}

	for i = #bags, 1, -1 do
		local item = bags[i]
		if select(2, GetContainerNumFreeSlots(item.bag)) > 0 then
		else
			if item and item.name and not item.empty then
				map[i] = item
			end
		end
	end

	-- Sorted table of items
	table.sort(map, sort)

	local reverse = {}
	for k, v in pairs(map) do
		reverse[v] = k
	end

	-- Second pass to put them into the correct location
	local final = {}
	for k, v in pairs(map) do
		-- Move map[k] -> bags[k], need to update the location of
		-- map[k]
		final[#final + 1] = { v.bag, v.slot, bags[k].bag, bags[k].slot, v.quality }

		local a = table.remove(bags, k)
		table.insert(bags, v.pos, a)
		v.pos = k
		local bag, slot = a.bag, a.slot
		a.bag = v.bag
		a.slot = v.slot

		a = map[revese[a]]
		a.bag = bag
		a.slot = slot
		-- Is this the end?
	end

	-- Debug sanity pass
	for k, v in ipairs(final) do
		if final[k + 1] then
			if final[k][5] < final[k + 1][5] then
				print(string.format("wrong place at (%d, %d)", final[k][1], final[k][2]))
			end
		end
	end

	return final
end

local moveItem = function(fromBag, fromSlot, toBag, toSlot)
	while true do
		local _, _, locked1 = GetContainerItemInfo(fromBag, fromSlot)
		local _, _, locked2 = GetContainerItemInfo(toBag, toSlot)
		if locked1 or locked2 then
			coroutine.yield()
		else
			break
		end
	end

	if fromBag ~= toBag or fromSlot ~= toSLot then
		print(string.format("Moving (%d, %d) -> (%d, %d)", fromBag, fromSlot, toBag, toSlot))
		PickupContainerItem(fromBag, fromSlot)
		PickupContainerItem(toBag, toSlot)
	end
end

local walkJob = function(job)
	if f:IsShown() then
		queue[# queue + 1] = job
		return
	end

	jobList = job()

	f:Show()
end

-- walkJob(defragMap)
-- walkJob(sortMap)

f:SetScript("OnUpdate", function(self, elapsed)
	timer = timer + elapsed
	if timer < speed then return end

	if jobList and next(jobList) then
		if not moveJob or coroutine.status(moveJob) == "dead" then
			moveJob = coroutine.create(moveItem)
			job = table.remove(jobList, 1)
			coroutine.resume(moveJob, unpack(job))

		elseif coroutine.status(moveJob) == "suspended" then
			coroutine.resume(moveJob, unpack(job))
		end
	else
		jobList = nil
		moveJob = nil
		job = nil

		self:Hide()
		if #queue > 0 then
			walkJob(table.remove(queue, 1))
		end
	end

	timer = 0
end)
SlashCmdList["FRAGGER"] = function(str)
	walkJob(defragMap)
	walkJob(sortMap)
end

SLASH_FRAGGER1 = "/fragger"

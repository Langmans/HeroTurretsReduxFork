local turret_state_transfer = {}

local report_transfer_issue = function(kind, entity, details)
	log("HeroTurrets " .. kind .. " transfer warning: " .. details)
	if game == nil then return end
	local msg = "[HeroTurretsReduxFork] " .. kind .. " transfer warning during rank-up on " .. (entity and entity.name or "unknown turret") .. ": " .. details
	if storage ~= nil and storage.heroturrets ~= nil then
		local state = storage.heroturrets
		local key_prefix = kind:gsub("%s+", "_")
		local tick_key = key_prefix .. "_copy_warn_tick"
		local count_key = key_prefix .. "_copy_warn_count"
		if state[tick_key] == nil or (game.tick - state[tick_key]) > 600 then
			game.print(msg)
			state[tick_key] = game.tick
		end
		state[count_key] = (state[count_key] or 0) + 1
	else
		game.print(msg)
	end
end

local report_ammo_copy_issue = function(entity, ammo_stack, details)
	report_transfer_issue("ammo", entity, details)
end

local report_fluid_copy_issue = function(entity, details)
	report_transfer_issue("fluid", entity, details)
end

local report_energy_copy_issue = function(entity, details)
	report_transfer_issue("energy", entity, details)
end

---@class HeroAmmoStackState
---@field slot_index integer
---@field name string
---@field count integer
---@field quality any
---@field ammo number|nil
---@field health number|nil

---@class HeroFluidboxState
---@field contents table<integer, any>
---@field filters table<integer, any>

---@class HeroTurretTransferState
---@field ammo HeroAmmoStackState[]|nil
---@field fluidbox HeroFluidboxState|nil
---@field energy number|nil

---@class HeroTurretTransferRestoreOptions
---@field ammo boolean|nil
---@field fluidbox boolean|nil
---@field energy boolean|nil

---@param entity LuaEntity
---@return LuaInventory|nil
local get_turret_ammo_inventory = function(entity)
	local ok_get_inventory, inv = pcall(function()
		return entity.get_inventory(defines.inventory.turret_ammo)
	end)
	if not ok_get_inventory then return nil end
	return inv
end

---@param entity LuaEntity
---@return HeroAmmoStackState[]|nil
local capture_ammo_inventory_state = function(entity)
	local inv = get_turret_ammo_inventory(entity)
	if inv == nil then return nil end

	local ammo_stacks = {}
	for slot_index = 1, #inv do
		local ok_stack, stack = pcall(function() return inv[slot_index] end)
		if not ok_stack then stack = nil end
		if type(stack) == "table" and stack.valid_for_read then
			---@cast stack LuaItemStack
			table.insert(ammo_stacks, {
				slot_index = slot_index,
				name = stack.name,
				count = stack.count,
				quality = stack.quality,
				ammo = stack.ammo,
				health = stack.health
			})
		end
	end

	if #ammo_stacks == 0 then return nil end
	return ammo_stacks
end

---@param source_entity LuaEntity
---@param new_entity LuaEntity
---@param ammo_stacks HeroAmmoStackState[]|nil
local restore_ammo_inventory_state = function(source_entity, new_entity, ammo_stacks)
	if ammo_stacks == nil then return end

	local inv = get_turret_ammo_inventory(new_entity)
	if inv == nil then return end

	for _, ammo_stack in ipairs(ammo_stacks) do
		local insert_data = {
			name = ammo_stack.name,
			count = ammo_stack.count,
			quality = ammo_stack.quality,
			ammo = ammo_stack.ammo,
			health = ammo_stack.health
		}

		local restored_in_slot = false
		if ammo_stack.slot_index ~= nil then
			local ok_slot, slot = pcall(function() return inv[ammo_stack.slot_index] end)
			if not ok_slot then slot = nil end
			if slot ~= nil then
				local ok_set, set_result = pcall(function() return slot.set_stack(insert_data) end)
				if ok_set and set_result == true then
					restored_in_slot = true
				end
			end
		end

		if not restored_in_slot then
			local ok, inserted = pcall(inv.insert, insert_data)
			if not ok then
				report_ammo_copy_issue(source_entity, ammo_stack, "insert failed for " .. ammo_stack.name .. " (slot " .. tostring(ammo_stack.slot_index) .. ")")
			elseif inserted ~= ammo_stack.count then
				report_ammo_copy_issue(source_entity, ammo_stack, "partial insert for " .. ammo_stack.name .. " (requested " .. ammo_stack.count .. ", inserted " .. inserted .. ", slot " .. tostring(ammo_stack.slot_index) .. ")")
			end
		end
	end
end

---@param entity LuaEntity
---@return any|nil
local get_entity_fluidbox = function(entity)
	local ok, fluidbox = pcall(function() return entity["fluidbox"] end)
	if ok and fluidbox ~= nil then return fluidbox end

	-- Keep a guarded fallback for mods/docs that still reference fluid_box.
	local ok_legacy, legacy_fluidbox = pcall(function() return entity["fluid_box"] end)
	if ok_legacy and legacy_fluidbox ~= nil then return legacy_fluidbox end

	return nil
end

---@param entity LuaEntity
---@return HeroFluidboxState|nil
local capture_fluidbox_state = function(entity)
	local fluidbox = get_entity_fluidbox(entity)
	if fluidbox == nil then return nil end

	local state = {
		contents = {},
		filters = {}
	}

	for i = 1, #fluidbox do
		local has_content, content = pcall(function() return fluidbox[i] end)
		if has_content and content ~= nil then
			if type(content) == "table" then
				state.contents[i] = {
					name = content.name,
					amount = content.amount,
					temperature = content.temperature
				}
			else
				state.contents[i] = content
			end
		end

		local get_filter = fluidbox["get_filter"]
		if type(get_filter) == "function" then
			local has_filter, filter = pcall(function() return get_filter(fluidbox, i) end)
			if has_filter and filter ~= nil then
				state.filters[i] = filter
			end
		end
	end

	if next(state.contents) == nil and next(state.filters) == nil then
		return nil
	end

	return state
end

---@param entity LuaEntity
---@param state HeroFluidboxState|nil
local restore_fluidbox_state = function(entity, state)
	if state == nil then return end

	local fluidbox = get_entity_fluidbox(entity)
	if fluidbox == nil then
		report_fluid_copy_issue(entity, "destination has no fluidbox/fluid_box")
		return
	end

	local set_filter = fluidbox["set_filter"]
	if state.filters ~= nil and type(set_filter) == "function" then
		for i, filter in pairs(state.filters) do
			local ok_set_filter = pcall(function() set_filter(fluidbox, i, filter) end)
			if not ok_set_filter then
				report_fluid_copy_issue(entity, "failed to restore filter at slot " .. tostring(i))
			end
		end
	end

	if state.contents ~= nil then
		for i, content in pairs(state.contents) do
			local ok_set_content = pcall(function() fluidbox[i] = content end)
			if not ok_set_content then
				local content_name = type(content) == "table" and content.name or tostring(content)
				report_fluid_copy_issue(entity, "failed to restore content at slot " .. tostring(i) .. " (" .. tostring(content_name) .. ")")
			end
		end
	end
end

---@param entity LuaEntity
---@return number|nil
local capture_energy_state = function(entity)
	local ok, energy = pcall(function() return entity.energy end)
	if not ok or type(energy) ~= "number" then return nil end
	return energy
end

---@param entity LuaEntity
---@param energy number|nil
local restore_energy_state = function(entity, energy)
	if energy == nil then return end
	local ok_set_energy = pcall(function() entity.energy = energy end)
	if not ok_set_energy then
		report_energy_copy_issue(entity, "failed to restore energy value")
	end
end

---@param entity LuaEntity
---@return HeroTurretTransferState
function turret_state_transfer.capture(entity)
	return {
		ammo = capture_ammo_inventory_state(entity),
		fluidbox = capture_fluidbox_state(entity),
		energy = capture_energy_state(entity)
	}
end

---@param source_entity LuaEntity
---@param new_entity LuaEntity
---@param state HeroTurretTransferState|nil
---@param options HeroTurretTransferRestoreOptions|nil
function turret_state_transfer.restore(source_entity, new_entity, state, options)
	if state == nil then return end
	if options == nil then options = {} end

	local restore_energy = options.energy
	if restore_energy == nil then restore_energy = true end
	if restore_energy then
		restore_energy_state(new_entity, state.energy)
	end

	local restore_fluidbox = options.fluidbox
	if restore_fluidbox == nil then restore_fluidbox = true end
	if restore_fluidbox then
		restore_fluidbox_state(new_entity, state.fluidbox)
	end

	local restore_ammo = options.ammo
	if restore_ammo == nil then restore_ammo = true end
	if restore_ammo then
		restore_ammo_inventory_state(source_entity, new_entity, state.ammo)
	end
end

return turret_state_transfer

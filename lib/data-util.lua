require '__nuclear-overhaul__.lib.paths'

local lib = {}

-- ============================================================================
-- DEBUG UTILS LIBRARY
if _DEBUG == nil then
  _DEBUG = false
end

lib.debug = {}

function lib.debug.log(data)
  if _DEBUG and (type(data) ~= 'function') then
    log(serpent.block(data))
  end
end

-- ============================================================================
-- STRING UTIL LIBRARY
lib.string = {}

---@param inputstr string
---@param start string
function lib.string.startsWith(inputstr, start) 
  return inputstr:sub(1, #start) == start 
end

---@param inputstr string
---@param ending string
function lib.string.endsWith(inputstr, ending)
  return ending == '' or inputstr:sub(-#ending) == ending
end


---@param inputstr string
---@param sub string
function lib.string.contains(inputstr, sub)
  return inputstr:find(sub, 1, true) ~= nil
end

---@param s string
---@param old string
---@param new string
function lib.string.replace(s, old, new)
  local search_start_idx = 1

  while true do
      local start_idx, end_idx = s:find(old, search_start_idx, true)
      if (not start_idx) then
          break
      end

      local postfix = s:sub(end_idx + 1)
      s = s:sub(1, (start_idx - 1)) .. new .. postfix

      search_start_idx = -1 * postfix:len()
  end

  return s
end

-- Multiply String Value
---@param text string
---@param coefficient number
function lib.string.msv(text, coefficient)
  if not text then return nil end
  local n, _ = string.gsub(text, '%a', '')
  local s = string.match(text, '%a+')
  return tostring(tonumber(n) * coefficient) .. s
end
local msv = lib.string.msv

---@param name string
function lib.string.find_base(name)
  return string.gsub(name, '^sp%-([1-9][0-9]?)%-', '')
end

-- ============================================================================
-- TABLE UTIL LIBRARY
lib.table = {}

function lib.table.contains(tbl, x)
  for _, v in pairs(tbl) do
    if v == x then 
    return true 
    end
  end
  return false
end

function lib.table.size(tbl)
  local count = 0
  for _, v in pairs(tbl) do
    count = count + 1
  end
  return count
end

--=================================================================================================

local function has_ingredient(recipe, ingredient)
  if recipe ~= nil and recipe.ingredients ~= nil then
    for i, existing in pairs(recipe.ingredients) do
      if existing[1] == ingredient or existing.name == ingredient then
        return true
      end
    end
  end
  return false
end

local function add_ingredient(recipe, ingredient, quantity, is_fluid)
  if recipe ~= nil and recipe.ingredients ~= nil then
    for i, existing in pairs(recipe.ingredients) do
      if existing[1] == ingredient or existing.name == ingredient then
        return
      end
    end
    if is_fluid then
      table.insert(recipe.ingredients, { type = 'fluid', name = ingredient, amount = quantity})
    else
      table.insert(recipe.ingredients, { ingredient, quantity })
    end
  end
end

local function replace_ingredient(recipe, old, new, amount, multiply)
  if recipe ~= nil and recipe.ingredients ~= nil then
    for i, existing in pairs(recipe.ingredients) do
      if existing[1] == new or existing.name == new then
        if existing.amount then existing.amount = amount end
        if existing[2] then existing[2] = amount end
        return
      end
    end
    for i, ingredient in pairs(recipe.ingredients) do 
      if ingredient.name == old then 
        ingredient.name = new 
        if amount then
          if multiply then
            ingredient.amount = math.ceil(amount * ingredient.amount)
          else
            ingredient.amount = amount
          end
        end
      end
      if ingredient[1] == old then 
        ingredient[1] = new
        if amount then
          if multiply then
            ingredient[2] = math.ceil(amount * ingredient[2])
          else
            ingredient[2] = amount
          end
        end
      end
		end
	end
end

local function remove_ingredient(recipe, old)
  index = -1
  if recipe ~= nil and recipe.ingredients ~= nil then
    for i, ingredient in pairs(recipe.ingredients) do 
      if ingredient.name == old or ingredient[1] == old then
        index = i
        break
      end
    end
    if index > -1 then
      table.remove(recipe.ingredients, index)
    end
  end
end

local function multiply_recipe(recipe, multiple)
  if recipe then
    if recipe.energy_required then
      recipe.energy_required = recipe.energy_required * multiple
    else
      recipe.energy_required = 0.5 * multiple  -- 0.5 is factorio default
    end
    if recipe.result_count then
      recipe.result_count = math.ceil(recipe.result_count * multiple)
    end
    if recipe.results then
      for i, result in pairs(recipe.results) do
        if result.name then
          if result.amount then
            result.amount = math.ceil(result.amount * multiple)
          end
          if result.amount_min ~= nil then
            result.amount_min = math.ceil(result.amount_min * multiple)
            result.amount_max = math.ceil(result.amount_max * multiple)
          end
          if result.catalyst_amount then
            result.catalyst_amount = math.ceil(result.catalyst_amount * multiple)
          end
        end
        if result[1] then
          result[2] = math.ceil(result[2] * multiple)
        end
      end
    end
    if not recipe.results and not recipe.result_count then
      -- implicit one item result
      recipe.result_count = math.ceil(multiple)
    end
    if recipe.ingredients then
      for i, ingredient in pairs(recipe.ingredients) do
        if ingredient.name then
          ingredient.amount = math.ceil(ingredient.amount * multiple)
        end
        if ingredient[1] then
          ingredient[2] = math.ceil(ingredient[2] * multiple)
        end
      end
    end
  end
end

-- ============================================================================

-- SET the unit count for a given technology
function lib.set_unit_count(tech_name, value)
  if not technology then
    return
  end
  for _, t in pairs({technology, technology.normal, technology.expensive}) do
    if t and t.unit then
      t.unit.count = value
      t.unit.count_formula = nil
    end
  end
end

function lib.has_prerequisite(tech_name, prerequisite)
  local technology = data.raw.technology[tech_name]
  for _, name in pairs(technology.prerequisites or {}) do
    if name == prerequisite then
      return true
    end
  end
  return false
end

-- ADD a prerequisite to a given technology
function lib.add_prerequisite(tech_name, prerequisite)
  local technology = data.raw.technology[tech_name]
  if not technology then
    log(tech_name)
    return
  end
  for _, name in pairs(technology.prerequisites) do
    if name == prerequisite then
      return
    end
  end
  table.insert(technology.prerequisites, prerequisite)
end

-- REPLACE a prerequisite with another
function lib.replace_prerequisite(tech_name, old, new)
  lib.remove_prerequisite(tech_name, old)
  lib.add_prerequisite(tech_name, new)
end

-- REMOVE a prerequisite from a given tech
function lib.remove_prerequisite(tech_name, prerequisite)
  local technology = data.raw.technology[tech_name]
  if not technology then
    log(tech_name)
    return
  end
  for i, name in pairs(technology.prerequisites or {}) do
    if name == prerequisite then
      table.remove(technology.prerequisites, i)
    end
  end
end

-- ADD science pack to a given tech
function lib.add_research_ingredient(tech_name, ingredient)
  local technology = data.raw.technology[tech_name]
  for _, name in pairs(technology.unit.ingredients) do
    if name[1] == ingredient then
      return
    end
  end
  table.insert(technology.unit.ingredients, {ingredient, 1 })
end

-- REPLACE a science pack with another
function lib.replace_research_ingredient(tech_name, old, new)
  lib.remove_research_ingredient(tech_name, old)
  lib.add_research_ingredient(tech_name, new)
end

-- REMOVE science pack to a given tech
function lib.remove_research_ingredient(tech_name, ingredient)
  local technology = data.raw.technology[tech_name]
  for i, name in pairs(technology.unit.ingredients) do
    if name[1] == ingredient then
      table.remove(technology.unit.ingredients, i)
    end
  end
end

function lib.has_recipe_effect(technology_name, effect)
  if effect.type ~= 'recipe-unlock' then
    return false
  end
  local technology = data.raw.technology[technology_name]
  for _, eff in pairs(technology.effects or {}) do
    if (eff.type == effect.type) and (eff.recipe == effect.recipe) then
      return true
    end
  end
  return false
end

-- ADD an effect to a given technology
function lib.add_effect(technology_name, effect, insert_safe)
  local safety = insert_safe or false
  local technology = data.raw.technology[technology_name]
  if technology then
    if not technology.effects then
      technology.effects = {}
    end
    
    if effect and effect.type == 'unlock-recipe' then
      if safety and not data.raw.recipe[effect.recipe] then
        return
      end
      if not lib.has_recipe_effect(technology_name, effect) then
        table.insert(technology.effects, effect)
      end
    end
  end
end

-- ADD an effect to a given technology to unlock recipe
function lib.add_unlock(technology_name, recipe)
  lib.add_effect(technology_name, { type = 'unlock-recipe', recipe = recipe })
end

-- REMOVE recipe unlock effect from a given technology, multiple times if necessary
function lib.remove_recipe_effect(technology_name, recipe_name)
  local technology = data.raw.technology[technology_name]
  local index = -1
  local cnt = 0
  if technology and technology.effects then
    for i, effect in pairs(technology.effects) do
      if effect.type == 'unlock-recipe' and effect.recipe == recipe_name then
        index = i
        cnt = cnt + 1
      end
    end
    if index > -1 then
      table.remove(technology.effects, index)
      if cnt > 1 then -- not over yet, do it again
        lib.remove_recipe_effect(technology_name, recipe_name)
      end
    end
  end
end

-- REMOVE all instances of unlocks for a given recipe
function lib.remove_all_recipe_effects(recipe_name)
  for name, _ in pairs(data.raw.technology) do
    lib.remove_recipe_effect(name, recipe_name)
  end
end

-- MOVE an unlock from a technology to another
function lib.move_recipe_unlock(recipe_name, old_tech, new_tech)
  lib.remove_recipe_effect(old_tech, recipe_name)
  lib.add_unlock(new_tech, recipe_name)
end

function lib.disable_recipe(recipe_name)
  local recipe = data.raw.recipe[recipe_name]
  if recipe then
    recipe.enabled = false
  end
end

-- ADD recipe to productivity whitelisted limitations
function lib.whitelist_productivity(recipe_name)
  for _, module in pairs(data.raw.module) do
    if module.category == 'productivity' and module.limitation then
      table.insert(module.limitation, recipe_name)
    end
  end
end

-- Returns true if a recipe has an ingredient
function lib.has_ingredient(recipe_name, ingredient)
  return data.raw.recipe[recipe_name] and (
    has_ingredient(data.raw.recipe[recipe_name], ingredient) or
    has_ingredient(data.raw.recipe[recipe_name].normal, ingredient))
end

-- ADD a given quantity of ingredient to target recipe
function lib.add_ingredient(recipe_name, ingredient, quantity)
  local is_fluid = not not data.raw.fluid[ingredient]
  if data.raw.recipe[recipe_name] and (data.raw.item[ingredient] or is_fluid) then
    add_ingredient(data.raw.recipe[recipe_name], ingredient, quantity, is_fluid)
    add_ingredient(data.raw.recipe[recipe_name].normal, ingredient, quantity, is_fluid)
    add_ingredient(data.raw.recipe[recipe_name].expensive, ingredient, quantity, is_fluid)
  end
end

-- REPLACE one ingredient with another in a recipe
--    Use amount to set an amount. If that amount is a multiplier instead of an exact amount, set multiply true.
function lib.replace_ingredient(recipe_name, old, new, amount, multiply)
  if data.raw.recipe[recipe_name] and (data.raw.item[new] or data.raw.fluid[new]) then
    replace_ingredient(data.raw.recipe[recipe_name], old, new, amount, multiply)
    replace_ingredient(data.raw.recipe[recipe_name].normal, old, new, amount, multiply)
    replace_ingredient(data.raw.recipe[recipe_name].expensive, old, new, amount, multiply)
  end
end

-- REMOVE an ingredient from a recipe
function lib.remove_ingredient(recipe_name, old)
  if data.raw.recipe[recipe_name] then
    remove_ingredient(data.raw.recipe[recipe_name], old)
    remove_ingredient(data.raw.recipe[recipe_name].normal, old)
    remove_ingredient(data.raw.recipe[recipe_name].expensive, old)
  end
end

-- MULTIPLY the cost, energy, and results of a recipe by a multiple
function lib.multiply_recipe(recipe_name, multiple, options)
  if data.raw.recipe[recipe_name] then
    multiply_recipe(data.raw.recipe[recipe_name], multiple)
    multiply_recipe(data.raw.recipe[recipe_name].normal, multiple)
    multiply_recipe(data.raw.recipe[recipe_name].expensive, multiple)
	end
end

--=================================================================================================

local function lr_hr_tint(obj, tint)
  if not obj then return end
  obj.tint = tint
  if obj.hr_version ~= nil then obj.hr_version.tint = tint end
end

local function tint_layers(obj, tint)
  if not obj then return end
  if obj.filename then lr_hr_tint(obj, tint) end
  if obj.layers and obj.layers[1] then lr_hr_tint(obj.layers[1], tint) end
  for _, d in pairs({ 'north', 'east', 'south', 'west' }) do tint_layers(obj[d], tint) end
end

function apply_tint(obj, tint)
  if not obj or not tint or type(obj) ~= 'table' then return end
  obj.icons = {{ icon = obj.icon, tint = tint }}
  tint_layers(obj.animation, tint)
  tint_layers(obj.horizontal_animation, tint)
  tint_layers(obj.vertical_animation, tint)
  tint_layers(obj.structure, tint)
  tint_layers(obj.patch, tint)
  tint_layers(obj.picture, tint)
  if obj.graphics_set then tint_layers(obj.graphics_set.animation, tint) end
  if obj.wet_mining_graphics_set then tint_layers(obj.wet_mining_graphics_set.animation, tint) end
  for _, fb in pairs(obj.fluid_boxes or {}) do 
    if type(fb) == 'table' then tint_layers(fb.pipe_picture, tint) end
  end
  for _, wv in pairs(obj.working_visualisations or {}) do tint_layers(wv.animation, tint) end
end

local function r_copy(target, source)
  for k, v in pairs(source) do
    if tostring(k):find('^_') ~= 1 then
      if type(v) == 'table' then
        target[k] = target[k] or {}
        r_copy(target[k], source[k])
      else
        target[k] = source[k]
      end
    end
  end
end

--- Updates (overwriting) a given prototype's fields with the given data
---@param obj ConfigData
function lib.update_prototype(obj)
  if not obj or not obj.name or not obj.type then error('Invalid object') return end
  local p = data.raw[obj.type][obj.name]
  if not p then log('Could not update ' .. obj.name) return end
  r_copy(p, obj)
end

--- Updates (overwriting) a given prototype's fields with the given data
---@param tbl table<ConfigData>
function lib.update_prototypes(tbl)
  for _, obj in pairs(tbl) do
    lib.update_prototype(obj)
  end
end

--- Creates a copy of the given prototype, using the additional fields to set new properties
---@param obj ConfigData
function lib.make_tier(obj)
  local base = table.deepcopy(data.raw[obj.type][obj._base])
  if not base then error('Could not find ' .. obj.type .. '/' .. obj._base) return end
  base.next_upgrade = nil
  r_copy(base, obj)
  if base.minable and base.minable.result then
    base.minable.result = base.name
  end
  if obj._tint and obj._tint ~= false then
    apply_tint(base, obj._tint)
  end
  return base
end

--=================================================================================================

return lib
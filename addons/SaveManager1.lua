
local httpService = game:GetService('HttpService')

local SaveManager = {} do
	SaveManager.Folder = 'ShiraHubSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = 'Toggle', idx = idx, value = object.Value } 
			end,
			Load = function(idx, data)
				if Toggles[idx] then 
					Toggles[idx]:Set(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:Set(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, mutli = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:Set(data.value)
				end
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:Set(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end
			if self.Parser['Toggle'] then
				table.insert(data.objects, self.Parser['Toggle'].Save(idx, toggle))
			end
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end
			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end)
			end
		end

		return true
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')

			local success, err = self:Load(name)
			if not success then
				return shirahub('Failed to load autoload config: ' .. err)
			end

			shirahub(string.format('Auto loaded config "%s"', name))
		end
	end

	-- Adapted BuildConfigSection for ShiraHub Items API
	function SaveManager:BuildConfigSection(configSection)
		-- Config name input via AddPanel
		configSection:AddPanel({
			Title = "Config Manager",
			Content = "Enter a name then use the buttons below.",
			Placeholder = "config name...",
			Button = "Save",
			ButtonCallback = function(text)
				if text:gsub(' ', '') == '' then
					shirahub('Invalid config name (empty)')
					return
				end
				local success, err = self:Save(text)
				if not success then
					shirahub('Failed to save config: ' .. err)
					return
				end
				shirahub(string.format('Saved config "%s"', text))
				if Options.SaveManager_ConfigList then
					Options.SaveManager_ConfigList:Set(nil)
				end
			end,
		})

		-- Config list dropdown
		Options.SaveManager_ConfigList = configSection:AddDropdown({
			Title = "Config List",
			Values = self:RefreshConfigList(),
			Default = nil,
			Multi = false,
		})

		-- Load button
		configSection:AddButton({
			Title = "Load Config",
			Callback = function()
				local name = Options.SaveManager_ConfigList and Options.SaveManager_ConfigList.Value
				if not name then shirahub('No config selected') return end
				local success, err = self:Load(name)
				if not success then
					shirahub('Failed to load: ' .. err)
					return
				end
				shirahub(string.format('Loaded config "%s"', name))
			end,
			SubTitle = "Refresh List",
			SubCallback = function()
				if Options.SaveManager_ConfigList then
					Options.SaveManager_ConfigList:Set(nil)
				end
				shirahub('Config list refreshed')
			end,
		})

		-- Overwrite button
		configSection:AddButton({
			Title = "Overwrite Config",
			Callback = function()
				local name = Options.SaveManager_ConfigList and Options.SaveManager_ConfigList.Value
				if not name then shirahub('No config selected') return end
				local success, err = self:Save(name)
				if not success then
					shirahub('Failed to overwrite: ' .. err)
					return
				end
				shirahub(string.format('Overwrote config "%s"', name))
			end,
			SubTitle = "Set Autoload",
			SubCallback = function()
				local name = Options.SaveManager_ConfigList and Options.SaveManager_ConfigList.Value
				if not name then shirahub('No config selected') return end
				writefile(self.Folder .. '/settings/autoload.txt', name)
				shirahub(string.format('Set "%s" as autoload', name))
			end,
		})

		self:SetIgnoreIndexes({ 'SaveManager_ConfigList' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
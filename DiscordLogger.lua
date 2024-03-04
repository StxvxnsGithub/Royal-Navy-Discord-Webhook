-- Discord Logger
local versionNo = 0.7

----------------------------------------------

local discord = {}

-- External
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local config = require(script.Config)
local url = config.url
local ownerPing = "<@" .. config.owner .. ">"

-- Settings
local failCount = 0 	-- KEEP AS ZERO
local maxFails = 10  	-- Maximum send fails allowed to avoid spamming the proxy
local interval = 30 	-- Seconds between sends

-- Testing
local testMode = false	-- Set to true if testing logger
local enabled = testMode or not RunService:IsStudio()

-- Variables
local sending = false
local queue = {}

----------------------------------------------

local placeID, placeName = "ERROR", "ERROR"
local placeLink = ""
local success, info = pcall(function()
	placeID = game.PlaceId
	return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
end)

if success and info  then
	placeName = info.Name
end

function discord.send()
	if #queue > 0 then
		if failCount < maxFails then
			local fields = queue
			queue = {}
			table.insert(fields,
				{
					["name"] = "",
					["value"] = "Version " .. versionNo .. " at [".. placeName .. "](https://www.roblox.com/games/" .. placeID ..")",
					["inline"] = false
				}
			)
			
			local body = {
				["embeds"] = {
					{
						["color"] = 263491,
						["fields"] = fields,
						["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S." .. math.round(tick() % 1 * 1000) .. "Z")
					}
				}
			}
			
			local success, response = pcall(function()
				return HttpService:PostAsync(url, HttpService:JSONEncode(body))
			end)
			
			if success then
				failCount = 0 -- Resets fail count upon successful send
				print("DISCORD LOGGER: messages logged.")
				return true
			else
				failCount += 1
				local responseBody = response.Body:ReadAsStringAsync()
				responseBody:GetAwaitResult()
				warn("DISCORD LOGGER: failed to log messages. ERROR: " .. response .. " " .. responseBody)
				print("DISCORD LOGGER: attempting error logging...")
				
				-- As error may be due to a data format error, attempts a simple error log
				task.delay(10, function()
					local secondarySuccess, secondaryResponse = pcall(function() 
						return HttpService:PostAsync(url, HttpService:JSONEncode({content = ownerPing .. " **ERROR:** message send failed. " .. response .. " " .. responseBody}))
					end)
					if secondarySuccess then
						print("DISCORD LOGGER: error logged.")
					else
						local secondaryResponseBody = response.Body:ReadAsStringAsync()
						secondaryResponseBody:GetAwaitResult()
						warn("DISCORD LOGGER: failed to log error. ERROR: " .. secondaryResponse .. "; SECONDARY ERROR: " .. secondaryResponseBody)
					end
				end)
			end
		elseif failCount == maxFails then -- Should only attempt logging a failure to the channel once
			failCount += 1
			warn("DISCORD LOGGER: failed to log messages. ERROR: send failed " .. (failCount-1) ..  " times. ACTION: halting script.")
			task.delay(10, function()
				HttpService:PostAsync(url, HttpService:JSONEncode({content = ownerPing .. " **ERROR:** message sending failed " .. (failCount-1) ..  " times. **ACTION:** halting script."}))
				
			end)
		end
		
		return false
	end
	
	return true
end

function discord.queue(method, message)
	if enabled then
		local queuedMessage = {
			["name"] = "",
			["value"] = message,
			["inline"] = false
		}
		table.insert(queue, queuedMessage) -- Add player to the list
		print("DISCORD LOGGER: " .. method .. " message queued. MESSAGE: " .. message)
		
		if not sending then
			sending = true
			
			task.delay(interval, function()
				local success, response = pcall(discord.send)
				sending = false

				if not success then
					warn("DISCORD LOGGER: failed to invoke send. ERROR: " .. response)
				end
			end)
		end 
	else
		warn("DISCORD LOGGER: not sent due to studio test server. " .. message)
	end
	
	return true
end

function discord.basicSend(message)
	if discord.queue("basic", message) then
		return true
	end

	warn("DISCORD LOGGER: basicSend failure")
	return false
end

function discord.playerSend(player, message)
	local displayName = player.DisplayName
	local playerName = player.Name
	local playerID = player.UserId
	
	if displayName == playerName then
		displayName = ""
	else
		displayName = " \"" .. displayName .. "\""
	end
	
	local playerMessage = "[" .. playerName .. displayName .. " (" .. playerID .. ")](https://www.roblox.com/users/" .. playerID .. ") " .. message
	
	if discord.queue("player", playerMessage) then
		return true
	end
	
	warn("DISCORD LOGGER: playerSend failure")
	return false
end

return discord

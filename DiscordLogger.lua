-- Discord Logger --
local versionNo = 0.5

----------------------------------------------

local discord = {}

-- External
local HttpService = game:GetService("HttpService")
local config = require(script.Config)
local url = config.url
local ownerPing = "<@" .. config.owner .. ">"

-- Settings
local failCount = 0 -- KEEP AS ZERO
local maxFails = 5  -- Maximum send fails allowed to avoid spamming the proxy

-- Ratelimiting
local queue = {}
local sending = false
local interval = 30 -- Seconds between sends

----------------------------------------------

function discord.send()
	if #queue > 0 then
		if failCount < maxFails then
			local placeID, placeName = "ERROR", "ERROR"
			local placeLink = ""
			local success, info = pcall(function()
				placeID = game.PlaceId
				return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
			end)
			
			if success and info  then
				placeName = info.Name
			end
			
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
				warn("DISCORD LOGGER: failed to log messages. ERROR: " .. response)
				print("DISCORD LOGGER: attempting error logging...")
				
				-- As error may be due to a data format error, attempts a simple error log
				local secondarySuccess, secondaryResponse = pcall(function() 
					return HttpService:PostAsync(url, HttpService:JSONEncode({content = ownerPing .. " **ERROR:** message send failed. " .. response}))
				end)
				if secondarySuccess then
					print("DISCORD LOGGER: error logged.")
				else
					warn("DISCORD LOGGER: failed to log error. ERROR: " .. response .. "; SECONDARY ERROR: " .. secondaryResponse)
				end
			end
		elseif failCount == maxFails then -- Should only attempt logging a failure to the channel once
			failCount += 1
			warn("DISCORD LOGGER: failed to log messages. ERROR: send failed " .. (failCount-1) ..  " times. ACTION: halting script.")
			HttpService:PostAsync(url, HttpService:JSONEncode({content = ownerPing .. " **ERROR:** message sending failed " .. (failCount-1) ..  " times. **ACTION:** halting script."}))
		end
		
		return false
	end
	
	return true
end

function discord.queue(method, message)
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
	local playerMessage = "[" .. player.Name .. "](https://www.roblox.com/users/" .. player.UserId .. ") " .. message
	
	if discord.queue("player", playerMessage) then
		return true
	end
	
	warn("DISCORD LOGGER: playerSend failure")
	return false
end

return discord

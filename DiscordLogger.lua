local discord = {}

-- External
local HttpService = game:GetService("HttpService")
local config = require(script.Config)
local url = config.url
local ownerPing = "<@" .. config.owner .. ">"

-- Settings
local failCount = 0 -- KEEP AS ZERO
local maxFails = 5  -- Maximum fails allowed to avoid spamming the proxy

----------------------------------------------

function discord.basicSend(message)
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
		
		local body = {
			["embeds"] = {
				{
					["color"] = 263491,
					["fields"] = {
						{
							["name"] = "",
							["value"] = message,
							["inline"] = false
						},
						{
							["name"] = "",
							["value"] = "[".. placeName .. "](https://www.roblox.com/games/" .. placeID ..")",
							["inline"] = false
						}
					},
					["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S." .. math.round(tick() % 1 * 1000) .. "Z")
				}
			}
		}

		local success, response = pcall(function()
			return HttpService:PostAsync(url, HttpService:JSONEncode(body))
		end)
		
		if success then
			failCount = 0 -- Resets fail count upon successful send
			print("Logged to RN Server: " .. message)
			return true
		else
			failCount += 1
			warn("Failed to log to RN Server. ERROR: " .. response)
			print("Attempting ERROR logging...")
			
			-- As error may be due to a data format error, attempts a simple (non-embed) error log
			local secondarySuccess, secondaryResponse = pcall(function() 
				return HttpService:PostAsync(url, HttpService:JSONEncode({content = ownerPing .. " **ERROR:** Message send failed " .. response}))
			end)
			if secondarySuccess then
				print("ERROR logged to RN Server.")
			else
				warn("Failed to log ERROR to RN Server. ERROR: " .. response .. " AND SECONDARY ERROR: " .. secondaryResponse)
			end
		end
	elseif failCount == maxFails then -- Should only attempt logging a failure to the channel once
		failCount += 1
		warn("Failed to log to RN Server. ERROR: Message send failed " .. (failCount-1) ..  " times. Halting script.")
		HttpService:PostAsync(url, HttpService:JSONEncode({content = ownerPing .. " **ERROR:** Message send failed " .. (failCount-1) ..  " times. Halting script."}))
	end
	
	--warn("Failed logging to RN Server: " .. message)
	return false
end

function discord.playerSend(player, message)
	local playerMessage = "[" .. player.Name .. "](https://www.roblox.com/users/" .. player.UserId .. ") " .. message
	
	if discord.basicSend(playerMessage) then
		return true
	end
	
	warn("Failed to log to RN Server. ERROR: playerSend failure")
	return false
end

return discord

-- Discord Logger
local versionNo = "0.11"

----------------------------------------------

local discord = {}

-- External
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local config = require(script.Config)
local url = config.url
local err = config.err
local ownerPing = "<@" .. config.owner .. ">"

-- Settings
local failCount = 0 	-- KEEP AS ZERO
local maxFails = 10  	-- Maximum send fails allowed to avoid spamming the proxy
local interval = 30 	-- Seconds between sends
local queueSize = 20	-- Maximum items allowed in the queue

-- Testing
local testMode = false	-- Set to true if testing logger
local enabled = testMode or not RunService:IsStudio()

-- Variables
local sending = false
local queue = {}
local errResponse, errBody

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

function discord.error(errorFields)
	local fields = errorFields
	table.insert(fields,
		{
			["name"] = "",
			["value"] = "Version " .. versionNo .. " at [".. placeName .. "](https://www.roblox.com/games/" .. placeID ..")",
			["inline"] = false
		}
	)
	local body = {
		["content"] = ownerPing,
		["embeds"] = {
			{
				["color"] = 13908037,
				["fields"] = fields,
				["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S." .. math.round(tick() % 1 * 1000) .. "Z")
			}
		}
	}
	
	local success, response = pcall(function()
		return HttpService:PostAsync(err, HttpService:JSONEncode(body)) -- Uses the webhook for errors
	end)
	if success then
		print("DISCORD LOGGER: error logged.")
		return true
	else
		local responseBody = response.Body:ReadAsStringAsync()
		responseBody:GetAwaitResult()
		warn("DISCORD LOGGER: failed to log error. ERROR: " .. response .. "; SECONDARY ERROR: " .. responseBody)
	end
	return false
end

function discord.send()
	if #queue > 0 then
		local fields = queue
		queue = {}
		if failCount < maxFails then
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
				print("DISCORD LOGGER: messages sent.")
				return true
			else
				failCount += 1
				local responseBody = response.Body:ReadAsStringAsync()
				responseBody:GetAwaitResult()
				errResponse, errBody = response, responseBody
				
				warn("DISCORD LOGGER: failed to send messages. ERROR: " .. response .. " " .. responseBody)
				print("DISCORD LOGGER: attempting error logging...")
				
				-- As error may be due to a data format error, attempts an error log to the backup
				local success, response = pcall(function()
					return discord.error({
						{["name"] = "ERROR OCCURED", ["value"] = "Message send failed.", ["inline"] = false},
						{["name"] = "ERROR DETAILS", ["value"] = errResponse .. " " .. errBody, ["inline"] = false}
					})
				end)
				if success then
					print("DISCORD LOGGER: error logged.")
					return true
				end
			end
		elseif failCount == maxFails then -- Should only attempt logging a failure to the channel once
			failCount += 1
			warn("DISCORD LOGGER: failed to send messages. ERROR: send failed " .. (failCount-1) ..  " times. ACTION: halting script.")

			local success, response = pcall(function()
				return discord.error({
					{["name"] = "ERROR OCCURED", ["value"] = "Failed to send messages " .. (failCount-1) ..  " times.", ["inline"] = false},
					{["name"] = "ERROR ACTIONS", ["value"] = "Halted script.", ["inline"] = false}
				})
			end)
		else
			warn("DISCORD LOGGER: halted due to errors. ERROR: " .. errResponse .. " " .. errBody)
		end
		return false
	else
		warn("DISCORD LOGGER: messages not sent. ERROR: queue empty.")
	end
	return true
end

function discord.queue(method, message)
	if enabled then
		table.insert(queue, message)
		
		if not sending then
			sending = true
			print("DISCORD LOGGER: " .. method .. " message sending in " .. interval .. "s. MESSAGE: " .. message.value)
			
			task.delay(interval, function()
				if sending then
					sending = false
					print("DISCORD LOGGER: messages sending.")
					
					local success, response = pcall(discord.send)
					if not success then
						warn("DISCORD LOGGER: failed to send. ERROR: " .. response)
						discord.queue("error", response)
					end
				end
			end)
		elseif #queue >= queueSize then
			sending = false
			warn("DISCORD LOGGER: forcing send due to queue capacity reached.")
			
			table.insert(queue, 
				{
					["name"] = "FORCED SEND",
					["value"] = "Message queue capacity reached",
					["inline"] = false
				}
			)
			
			local success, response = pcall(discord.send)
			if not success then
				warn("DISCORD LOGGER: failed to invoke forced send. ERROR: " .. response)
				discord.queue("error", response)
			end
		else
			print("DISCORD LOGGER: " .. method .. " message queued. MESSAGE: " .. message.value)
		end 
	else
		warn("DISCORD LOGGER: not sent due to studio test server. " .. message.value)
	end
	return true
end

function discord.basicSend(message)
	local embedMessage = {
		["name"] = "",
		["value"] = message,
		["inline"] = false
	}
	
	if discord.queue("basic", embedMessage) then
		return true
	end
	warn("DISCORD LOGGER: basicSend failure.")
	return false
end

function discord.playerSend(player, message)
	local displayName = player.DisplayName
	local playerName = player.Name
	local playerID = player.UserId
	
	if displayName == playerName then
		displayName = ""
	else
		displayName = " \"" .. displayName .. "\"" -- Output: "displayName"
	end
	
	local playerMessage = "[" .. playerName .. displayName .. " (" .. playerID .. ")](https://www.roblox.com/users/" .. playerID .. ") " .. message
	local embedMessage = {
		["name"] = "",
		["value"] = playerMessage,
		["inline"] = false
	}
	
	if discord.queue("player", embedMessage) then
		return true
	end
	warn("DISCORD LOGGER: playerSend failure.")
	return false
end

function discord.shutdown()
	if enabled then
		table.insert(queue, 
			{
				["name"] = "SERVER SHUTDOWN",
				["value"] = "Remaining queued messages logged",
				["inline"] = false
			}
		)

		local success, response = pcall(discord.send)
		if not success then
			warn("DISCORD LOGGER: failed to send remaining messages when shutting down. ERROR: " .. response)
			return false
		end
	end
	return true
end

return discord

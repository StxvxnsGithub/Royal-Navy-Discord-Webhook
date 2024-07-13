----------------------------------------------
-- Scripted by FederalDechart, federal#1678 --
----------------------------------------------

-- Discord Logger
local versionNo = "1.1"

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
local maxFails = 5  	-- Maximum send fails allowed to avoid spamming the proxy
local interval = 30 	-- Seconds between sends
local errDelay = 120	-- Seconds before error logging is attempted
local queueSize = 20	-- Maximum items allowed in the queue

-- Testing
local testMode = false	-- Set to true if testing logger
local enabled = testMode or not RunService:IsStudio()

-- Variables
local lastSend = 0
local queue = {}
local errCode, errStatus, errBody = "UNKNOWN", "UNKNOWN", "UNKNOWN"

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
				["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S", os.time() - errDelay) .. "Z"
			}
		}
	}
	
	local success, response = pcall(function()
		return HttpService:RequestAsync({
			Url = err,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json"
			},
			Body = HttpService:JSONEncode(body)
		})
	end)
	
	if success and response.Success then
		print("DISCORD LOGGER: error logged.")
		return true
	else
		warn("DISCORD LOGGER: failed to log error. ERROR: " .. response)
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
						["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S", os.time()) .. "Z"
					}
				}
			}

			local success, response = pcall(function()
				return HttpService:RequestAsync({
					Url = url,
					Method = "POST",
					Headers = {
						["Content-Type"] = "application/json"
					},
					Body = HttpService:JSONEncode(body)
				})
			end)
			
			if success and response.Success then
				print("DISCORD LOGGER: messages sent.")
				failCount = 0 -- Resets fail count upon successful send
				return true
			else
				failCount += 1			
				errCode, errStatus, errBody = response.StatusCode, response.StatusMessage, response.Body
				
				warn("DISCORD LOGGER: failed to send messages. ERROR: " .. errCode)
				
				-- Attempts an error log to the backup webhook after a delay
				task.delay(errDelay, function()
					local success, response = pcall(function()
						return discord.error({
							{["name"] = "ERROR OCCURED", ["value"] = "Message send failed.", ["inline"] = false},
							{["name"] = "ERROR DETAILS", ["value"] = "HTTP " .. errCode .. " (" .. errStatus .. ") - " .. errBody, ["inline"] = false}
						})
					end)
					if success then
						print("DISCORD LOGGER: attempting error logging...")
					end
				end)
			end
		elseif failCount == maxFails then -- Should only attempt logging a failure to the channel once
			failCount += 1
			warn("DISCORD LOGGER: failed to send messages. ERROR: send failed " .. (failCount-1) ..  " times. ACTION: halting script.")
			
			task.delay(errDelay, function()
				local success, response = pcall(function()
					return discord.error({
						{["name"] = "ERROR OCCURED", ["value"] = "Failed to send messages " .. (failCount-1) ..  " times.", ["inline"] = false},
						{["name"] = "ERROR ACTIONS", ["value"] = "Halted script.", ["inline"] = false}
					})
				end)
				if success then
					print("DISCORD LOGGER: attempting error logging...")
				end
			end)
		else
			warn("DISCORD LOGGER: halted due to errors. ERROR: HTTP " .. errCode .. " (" .. errStatus .. ") - " .. errBody)
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
		
		if os.time()-lastSend >= interval then
			lastSend = os.time()
			print("DISCORD LOGGER: " .. method .. " message sending. MESSAGE: " .. message.value)
			print("DISCORD LOGGER: sending messages.")

			local success, response = pcall(discord.send)
			if not success then
				warn("DISCORD LOGGER: failed to invoke send.")
				discord.basicSend("Failed to invoke send.")
			end
		elseif #queue >= queueSize then
			lastSend = os.time()
			print("DISCORD LOGGER: " .. method .. " message sending. MESSAGE: " .. message.value)
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
				warn("DISCORD LOGGER: failed to invoke forced send.")
				discord.basicSend("Failed to invoke forced send.")
			end
		else
			print("DISCORD LOGGER: " .. method .. " message queued. MESSAGE: " .. message.value)
			
			task.delay(interval, function()
				if #queue > 0 then
					lastSend = os.time()
					print("DISCORD LOGGER: sending due messages.")

					local success, response = pcall(discord.send)
					if not success then
						warn("DISCORD LOGGER: failed to invoke due send.")
						discord.basicSend("Failed to invoke due send.")
					end
				end
			end)
		end 
	else
		warn("DISCORD LOGGER: message not sent due to studio test server. " .. message.value)
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
		local status = "ERROR"
		if #queue > 0 then
			status = "Queued messages logged"
		else 
			status = "No queued messages"
		end
		
		table.insert(queue, 
			{
				["name"] = "SERVER SHUTDOWN",
				["value"] = status,
				["inline"] = false
			}
		)

		local success, response = pcall(discord.send)
		if not success or not response then
			warn("DISCORD LOGGER: failed to send remaining messages when shutting down.")
			return false
		end
	end
	return true
end

return discord

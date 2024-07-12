<h1 align="center">
  Royal Navy Discord Webhook
</h1>

<div align="center">
  A webhook to log actions for a ROBLOX Royal Navy milsim community.
</div>

## About

Sends HTTP Requests to a Discord webhook via [WebhookProxy](https://webhook.lewisakura.moe/) by [lewisakura](https://lewisakura.moe/). 

## Planned Features:
<ul>
  <li><s>Join/Leave Logging</s> COMPLETED</li>
  <li><s>Rate Limiting</s> COMPLETED</li>
  <li><s>Spawn Logs</s> COMPLETED</li>
  <li><s>Backup/secondary Webhook for error logging</s> COMPLETED</li>
  <li><s>Refactor/redesign message send delay</s> COMPLETED</li>
</ul>

## Changelog

Version 1.0:  
\- Rewrote queuing system for logs to improve reliability and robustness
\- Improved error handling for a higher chance of successfully detecting and logging errors

Version 0.11:  
\- Backup/secondary Webhook for error logging  

Version 0.10:  
\- Messages passing via parameters refactored  
\- Refactored server shutdown processing  
\- Added logging of server shutdowns

Version 0.9:  
\- Set maximum queue size to 20 (Discord embeds only support 25 fields)  
\- Send interval skipped when maximum queue size reached  

Version 0.8:  
\- Minor fixes  

Version 0.7:  
\- Modified error handling to catch failures  
\- Increased maximum fails allowed  
\- Added wait for error logging to Discord  

Version 0.6
\- Modified player display/link format to: UserName "DisplayName" (UserID)    
\- Unless testing boolean set to true, studio tests by default no longer send to the webhook  
\- Upon server shutdown, queued logs are forcibly sent
\- Programmed server join/leave logs  
\- Programmed seat logs  

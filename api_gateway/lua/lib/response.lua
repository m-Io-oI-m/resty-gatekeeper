--
-- lib/response.lua
-- Provides standardized functions for sending JSON responses.
--

local cjson = require "cjson.safe"

local _M = {}

--- Private helper to send a JSON response with a given status code.
-- @param status The HTTP status code.
-- @param data The Lua table to be encoded as the JSON response body.
local function send_json(status, data)
    ngx.status = status
    ngx.header.content_type = "application/json; charset=utf-8"
    ngx.say(cjson.encode(data))
    return ngx.exit(status)
end

--- Sends a standardized success response (HTTP 200-299).
-- @param data The payload for the 'data' field of the response.
-- @param status (Optional) The HTTP status code, defaults to 200.
function _M.success(data, status)
    return send_json(status or 200, {
        success = true,
        timestamp = ngx.time(),
        request_id = ngx.var.request_id,
        data = data or {}
    })
end

--- Sends a standardized error response (HTTP 400-599).
-- @param status The HTTP status code, defaults to 500.
-- @param message A descriptive error message.
-- @param details (Optional) Additional error details.
function _M.error(status, message, details)
    local response_body = {
        error = message,
        timestamp = ngx.time(),
        request_id = ngx.var.request_id
    }
    if details then
        response_body.details = details
    end
    return send_json(status or 500, response_body)
end

return _M
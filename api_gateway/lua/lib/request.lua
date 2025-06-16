--
-- lib/request.lua
-- Provides helper functions for handling incoming HTTP requests.
--

local cjson = require "cjson.safe"
local response = require "lib.response"

local _M = {}

--- Reads and decodes the JSON body from the current request.
-- Encapsulates reading and parsing, handling errors automatically.
-- @return A Lua table representing the decoded JSON on success.
-- @return On error, sends an appropriate HTTP error response and exits.
function _M.get_json_body()
    -- Ensure the request body has been read into memory.
    ngx.req.read_body()
    local body = ngx.req.get_body_data()

    if not body or body == "" then
        return response.error(400, "Request body is required")
    end

    -- Attempt to decode the body as JSON.
    local data, err = cjson.decode(body)
    if not data then
        return response.error(400, "Invalid JSON in request body", err)
    end

    return data
end

return _M
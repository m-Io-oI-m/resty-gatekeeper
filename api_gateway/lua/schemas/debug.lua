--
-- schemas/debug.lua
-- Defines and validates API endpoints for the 'public' service.
--

local compiler = require "lib.schema_compiler"

local _M = {}

-------------------------------------------------------------------------------
-- Schema Definition
-------------------------------------------------------------------------------

-- Schema for the root endpoint. It allows no query parameters.
local get_root_query_schema = {
    type = "object",
    properties = {},
    additionalProperties = false
}

-------------------------------------------------------------------------------
-- Endpoint Registry
-------------------------------------------------------------------------------
_M.endpoints = {
    ["GET"] = {
        ["^/$"] = compiler.compile(get_root_query_schema)
    }
}

--- Finds a validator for a given method and path pattern.
-- @param method The HTTP method (e.g., "GET").
-- @param path The request path within the service (e.g., "/").
-- @return A validator function, a sentinel value (true), or nil.
function _M.get_validator(method, path)
    local method_routes = _M.endpoints[method]
    if not method_routes then
        return nil
    end

    for pattern, validator_or_sentinel in pairs(method_routes) do
        local m, err = ngx.re.match(path, pattern, "jo")
        if err then
            ngx.log(ngx.ERR, "Regex error in 'public' schema validator: ", err)
            return nil
        end
        if m then
            return validator_or_sentinel
        end
    end

    return nil
end


return _M
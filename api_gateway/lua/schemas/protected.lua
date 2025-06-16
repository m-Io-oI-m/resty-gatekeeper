--
-- schemas/protected.lua
-- Defines and validates API endpoints for the 'protected' service.
--

local compiler = require "lib.schema_compiler"

local _M = {}

-------------------------------------------------------------------------------
-- Schema Definitions
-------------------------------------------------------------------------------

-- Schema for POST /items body
local post_items_body_schema = {
    type = "object",
    properties = {
        title = { type = "string", minLength = 1, maxLength = 20 },
        description = { type = "string", minLength = 1, maxLength = 200 },
        priority = { type = "string" }
    },
    required = { "title", "description" },
    additionalProperties = false
}

-- Schema for GET /items query parameters
local get_items_query_schema = {
    type = "object",
    properties = {
        status = { type = "string", enum = { "pending", "completed" } }
    },
    -- Allow other query params (e.g., for pagination) to pass through without validation.
    additionalProperties = true
}


-------------------------------------------------------------------------------
-- Endpoint Registry
-- Defines all valid endpoints for this service using regex patterns.
-- The value is the compiled validator function, or `true` if the endpoint
-- is valid but requires no query/body validation.
-------------------------------------------------------------------------------
_M.endpoints = {
    ["POST"] = {
        ["^/items$"] = compiler.compile(post_items_body_schema)
    },
    ["GET"] = {
        -- Endpoint for listing/searching items. Validates query params.
        ["^/items$"] = compiler.compile(get_items_query_schema),
        -- Endpoint for fetching a single item by ID. Path param, no query/body validation needed.
        ["^/items/[^/]+$"] = true,
        -- Root endpoint. No query/body validation needed.
        ["^/$"] = true
    }
}

--- Finds a validator for a given method and path pattern.
-- @param method The HTTP method (e.g., "GET").
-- @param path The request path within the service (e.g., "/items/123").
-- @return A validator function if validation is needed.
-- @return `true` if the route is valid but requires no validation.
-- @return `nil` if the route is not defined for the given method.
function _M.get_validator(method, path)
    local method_routes = _M.endpoints[method]
    if not method_routes then
        -- This HTTP method is not defined for any endpoint in this service.
        return nil
    end

    -- Loop through registered path patterns for the given method.
    for pattern, validator_or_sentinel in pairs(method_routes) do
        local m, err = ngx.re.match(path, pattern, "jo")
        if err then
            ngx.log(ngx.ERR, "Regex error in 'protected' schema validator for pattern '", pattern, "': ", err)
            -- This is a configuration error, fail securely.
            return nil
        end

        if m then
            -- A matching pattern was found. Return its validator or the `true` sentinel.
            return validator_or_sentinel
        end
    end

    -- No matching path pattern was found for this method.
    return nil
end

return _M
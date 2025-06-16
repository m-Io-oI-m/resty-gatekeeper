--
-- schemas/registry.lua
-- Pre-loads all known service schemas to provide a single, secure point of access
-- for the proxy handler. This avoids dynamic, path-based `require` calls.
--

local _M = {}

-- Manually register all service schemas that require validation.
local registered_schemas = {
    debug = require "schemas.debug",
    protected = require "schemas.protected",
    public = require "schemas.public"
    -- Add other service schemas here as they are created.
}

--- Finds the appropriate validator function for a given request.
-- This acts as a facade over the individual schema modules.
-- @param service_name The name of the service (e.g., "protected").
-- @param method The HTTP method (e.g., "GET").
-- @param path The request path within the service (e.g., "/items").
-- @return A validator function, a sentinel value (`true`), or `nil`.
function _M.get_validator(service_name, method, path)
    local service_schema_module = registered_schemas[service_name]

    if not service_schema_module or not service_schema_module.get_validator then
        -- This service does not have a registered schema module.
        -- We will assume no validation is required for any of its endpoints.
        return true -- Return sentinel to allow request to proceed.
    end

    return service_schema_module.get_validator(method, path)
end

return _M
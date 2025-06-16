--
-- handlers/proxy.lua
-- Dynamically routes incoming requests, performing authentication and
-- schema validation based on a predefined policy and schema registry.
--

local response = require "lib.response"
local auth = require "middleware.auth"
local request = require "lib.request"
local schema_registry = require "schemas.registry"

-- 1. Extract the service name and its internal path from the request URI.
-- e.g., /api/protected/items/123 -> service_name="protected", service_path="/items/123"
local m, err = ngx.re.match(ngx.var.uri, [[^/api/([^/]+)(/.*)?$]])
if not m then
    return response.error(404, "Not Found")
end
local service_name = m[1]
local service_path = m[2] or "/" -- Default to root path if not present

-- 2. Verify that the service is a registered upstream.
if not ngx.shared.upstreams:get(service_name) then
    return response.error(404, "Service not found")
end

-- 3. If the service requires authentication, execute the JWT validation logic.
local auth_required = ngx.shared.service_auth_config:get(service_name)
if auth_required == "true" then
    auth.authenticate() -- This function handles its own error responses.
end

-- 4. Perform Schema Validation based on the registered schema for the endpoint.
local method = ngx.var.request_method
local validator_or_sentinel = schema_registry.get_validator(service_name, method, service_path)

if validator_or_sentinel == nil then
    -- `nil` means the endpoint (method + path pattern) is not defined in its service's schema.
    return response.error(404, "Endpoint not found or method not allowed.")
end

if type(validator_or_sentinel) == "function" then
    -- A validator function was returned, so validation is required.
    local validator = validator_or_sentinel
    local data_to_validate
    local source_name

    if method == "POST" or method == "PUT" or method == "PATCH" then
        -- For methods with bodies, validate the JSON body.
        data_to_validate = request.get_json_body() -- This function handles parsing errors.
        source_name = "request body"
    else
        -- For other methods (GET, DELETE, etc.), validate query arguments.
        data_to_validate = ngx.req.get_uri_args()
        source_name = "query parameters"
    end

    local ok, validation_err = validator(data_to_validate)
    if not ok then
        return response.error(400, "Invalid " .. source_name, validation_err)
    end
end
-- If `validator_or_sentinel` was `true`, the endpoint is valid but needs no
-- specific validation, so we simply proceed.

-- 5. Rewrite the URI to the internal proxy path.
-- This is clearer and safer than using gsub for this task.
local internal_uri = "/internal/" .. service_name .. service_path

-- 6. Perform an internal redirect to the location that handles the actual proxying.
return ngx.exec(internal_uri, ngx.req.get_uri_args())

-- --
-- -- handlers/proxy.lua
-- -- Dynamically routes incoming requests based on URI and a predefined policy.
-- --

-- local response = require "lib.response"
-- local auth = require "middleware.auth"

-- -- 1. Extract the service name from the request URI (e.g., "protected" from /api/protected/path).
-- local m, err = ngx.re.match(ngx.var.uri, [[^/api/([^/]+)]])
-- if not m then
--     return response.error(404, "Not Found")
-- end
-- local service_name = m[1]

-- -- 2. Verify that the service is registered and look up its auth requirement.
-- if not ngx.shared.upstreams:get(service_name) then
--     return response.error(404, "Service not found")
-- end
-- local auth_required = ngx.shared.service_auth_config:get(service_name)

-- -- 3. If the service requires authentication, execute the JWT validation logic.
-- if auth_required == "true" then
--     auth.authenticate()
-- end

-- -- 4. Rewrite the URI from its public-facing path to the internal proxy path.
-- -- e.g., /api/protected/data -> /internal/protected/data
-- local internal_uri, n, err = ngx.re.gsub(ngx.var.uri, "^/api", "/internal", "jo")
-- if err then
--     ngx.log(ngx.ERR, "URI substitution failed: ", err)
--     return response.error(500, "Internal Server Error")
-- end

-- -- 5. Perform an internal redirect to the location that handles the actual proxying.
-- return ngx.exec(internal_uri, ngx.req.get_uri_args())
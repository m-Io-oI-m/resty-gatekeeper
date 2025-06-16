--
-- lib/upstream.lua
-- A wrapper for making internal, non-blocking requests to upstream services.
--

local cjson = require "cjson.safe"

local _M = {}

--- Performs an internal API request using `ngx.location.capture`.
-- Automatically handles JSON encoding of request bodies and decoding of response bodies.
-- @param uri The internal URI to request (e.g., "/internal/auth/login").
-- @param options A table of options for `ngx.location.capture` (e.g., method, body).
-- @return `http_status, response_body_table` on success.
-- @return `error_status, error_table` on failure.
function _M.capture(uri, options)
    -- If the body is a table, automatically encode it as JSON.
    if options.body and type(options.body) == "table" then
        options.body = cjson.encode(options.body)
        options.headers = options.headers or {}
        options.headers["Content-Type"] = "application/json"
    end

    -- Make a non-blocking internal subrequest.
    local res = ngx.location.capture(uri, options)

    if not res then
        ngx.log(ngx.ERR, "Internal request to '", uri, "' failed completely.")
        return 503, { error = "Service unavailable" }
    end

    -- Attempt to decode the response body as JSON.
    local response_body = {}
    if res.body and res.body ~= "" then
        response_body = cjson.decode(res.body)
        if not response_body then
            ngx.log(ngx.ERR, "Failed to decode JSON from upstream '", uri, "'. Body: ", res.body)
            return 502, { error = "Invalid response from upstream service" }
        end
    end

    return res.status, response_body
end

return _M
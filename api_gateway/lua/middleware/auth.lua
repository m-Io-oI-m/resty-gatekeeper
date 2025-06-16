--
-- middleware/auth.lua
-- Provides a reusable authentication function for handlers.
--

local jwt_validator = require "lib.jwt_validator"
local response = require "lib.response"
local cjson = require "cjson.safe"

local _M = {}

--- Verifies a JWT and prepares the request for upstream proxying.
-- On success, it removes the original Authorization header and injects `X-User-*` headers.
-- On failure, it sends a 401 Unauthorized response and terminates the request.
-- @return The JWT claims table on successful validation.
function _M.authenticate()
    -- 1. Verify the JWT's signature, claims, and revocation status.
    local ok, claims_or_err = jwt_validator.verify()
    if not ok then
        return response.error(401, ngx.HTTP_UNAUTHORIZED)
    end

    -- 2. For security, prevent the original token from reaching upstream services.
    ngx.req.clear_header("Authorization")

    -- 3. Propagate trusted user information to upstream services via headers.
    ngx.req.set_header("X-User-ID", claims_or_err.sub or "")
    ngx.req.set_header("X-User-Roles", cjson.encode(claims_or_err.roles or {}))
    ngx.req.set_header("X-JWT-JTI", claims_or_err.jti or "")
    ngx.req.set_header("X-JWT-EXP", claims_or_err.exp or "")

    -- 4. Return the claims for potential use in the calling handler.
    return claims_or_err
end

return _M
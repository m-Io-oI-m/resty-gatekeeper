--
-- handlers/auth_logout.lua
-- Handles the /api/auth/logout endpoint.
--

local response = require "lib.response"
local auth = require "middleware.auth"
local cookie = require "lib.cookie"
local token_service = require "lib.token_service"

-- 1. Authenticate the request to identify the user and token.
-- This terminates the request if authentication fails.
local claims = auth.authenticate()

-- 2. Revoke the token by adding its JTI to the Redis blocklist.
local ok, err = token_service.revoke(claims.jti, claims.exp)
if not ok then
    -- Log the error but proceed with logout for a better user experience.
    ngx.log(ngx.ERR, "Token revocation failed: ", err)
end

-- 3. Clear the authentication cookie from the user's browser.
cookie.clear()

-- 4. Return a success message to the client.
return response.success({ message = "Successfully logged out." })
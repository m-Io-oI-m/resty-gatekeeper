--
-- handlers/auth_login.lua
-- Handles the POST /api/auth/login endpoint.
--

local user_schema = require "schemas.user"
local response = require "lib.response"
local request = require "lib.request"
local upstream = require "lib.upstream"
local cookie = require "lib.cookie" 

-- 1. Read and validate the JSON request body.
local input = request.get_json_body()
local ok, validation_err = user_schema:validate(input)
if not ok then
    return response.error(400, "Validation failed", validation_err)
end

-- 2. Forward credentials to the internal authentication service.
local status, auth_data = upstream.capture("/internal/auth/login", {
    method = ngx.HTTP_POST,
    body = {
        username = input.username,
        password = input.password
    }
})

-- 3. Handle the response from the auth service.
if status ~= 200 then
    local error_msg = (auth_data and auth_data.error) or "Authentication failed"
    return response.error(status, error_msg)
end

-- 4. Ensure the auth service returned a valid token.
if not (auth_data and type(auth_data) == "table" and auth_data.token) then
    ngx.log(ngx.ERR, "Invalid success response from auth service")
    return response.error(502, "Invalid response from authentication service")
end

-- 5. Set a secure, HttpOnly cookie with the JWT.
cookie.set(auth_data.token)

-- 6. Return a success response to the client.
return response.success({
    token = auth_data.token,
    user = auth_data.user,
    expires_at = auth_data.expires_at
})
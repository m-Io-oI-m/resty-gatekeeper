--
-- lib/cookie.lua
-- Provides centralized and secure management of HTTP cookies.
--

local _M = {}

-- Centralizes cookie name and attributes for consistency and security.
local COOKIE_NAME = "auth_token"
local BASE_ATTRIBUTES = "Path=/; HttpOnly; SameSite=Strict"

--- Returns base cookie attributes, adding 'Secure' for HTTPS connections.
-- @return A string of cookie attributes.
local function get_secure_attributes()
    if ngx.var.scheme == "https" then
        return BASE_ATTRIBUTES .. "; Secure"
    end
    return BASE_ATTRIBUTES
end

--- Sets a secure, HttpOnly authentication cookie.
-- @param token The JWT or other token value to set.
function _M.set(token)
    if not token or token == "" then
        return
    end
    local attributes = get_secure_attributes()
    ngx.header["Set-Cookie"] = COOKIE_NAME .. "=" .. token .. "; " .. attributes
end

--- Clears the authentication cookie by setting its expiration to a past date.
function _M.clear()
    local attributes = get_secure_attributes()
    local expired_cookie = COOKIE_NAME .. "=; " .. attributes .. "; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
    ngx.header["Set-Cookie"] = expired_cookie
end

return _M
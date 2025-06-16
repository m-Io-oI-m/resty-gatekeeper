--
-- lib/token_service.lua
-- Handles business logic related to JWTs, such as revocation.
--

local redis_client = require "lib.redis_client"

local _M = {}

--- Revokes a JWT by adding its JTI to a Redis-based blocklist.
-- The JTI is stored in Redis with a TTL equal to the token's remaining validity.
-- @param jti The JWT ID (jti claim) to revoke.
-- @param exp The expiration timestamp (exp claim) of the JWT.
-- @return `true` on success, or `nil, error_message` on failure.
function _M.revoke(jti, exp)
    if not jti or jti == "" or not exp then
        return nil, "Valid JTI and EXP claims are required for revocation"
    end

    local ttl = exp - ngx.time()
    -- If the token has already expired, revocation is unnecessary.
    if ttl <= 0 then
        return true
    end

    -- Atomically set the key with the calculated expiration.
    local ok, err = redis_client.with_connection(function(redis_conn)
        return redis_conn:set("revoked_jti:" .. jti, "true", "EX", ttl)
    end)

    if not ok then
        ngx.log(ngx.ERR, "Failed to add JTI to Redis revocation list: ", err)
        return nil, "Server error during token revocation"
    end

    return true
end

return _M
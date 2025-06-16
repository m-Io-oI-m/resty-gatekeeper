--
-- lib/redis_client.lua
-- Provides a robust, pooled connection manager for Redis interactions.
--

local redis = require "resty.redis"

local _M = {}

-- Centralized configuration for Redis connections.
local REDIS_CONFIG = {
    host = os.getenv("REDIS_HOST") or "cache_service",
    port = tonumber(os.getenv("REDIS_PORT")) or 6379,
    timeout = 1000, -- ms
    pool_name = "default_redis_pool",
    pool_size = 100,
    pool_timeout = 60000 -- ms
}

--- Manages the Redis connection lifecycle for a given operation.
-- This higher-order function borrows a connection from the pool, executes a
-- user function with it, and guarantees the connection is returned to the pool.
-- @param user_function A function that accepts a Redis connection object.
-- @return The values returned by the `user_function`, or `nil, error_message` on connection failure.
function _M.with_connection(user_function)
    -- 1. Initialize a new Redis instance.
    local red = redis:new()
    red:set_timeouts(REDIS_CONFIG.timeout, REDIS_CONFIG.timeout, REDIS_CONFIG.timeout)

    -- 2. Connect to Redis, using a connection pool for efficiency.
    local ok, err = red:connect(REDIS_CONFIG.host, REDIS_CONFIG.port, { pool = REDIS_CONFIG.pool_name })
    if not ok then
        ngx.log(ngx.ERR, "failed to connect to redis: ", err)
        return nil, "redis connection error"
    end

    -- 3. Execute the provided function with the active connection.
    local result = { user_function(red) }

    -- 4. Return the connection to the pool for reuse.
    local ok, err = red:set_keepalive(REDIS_CONFIG.pool_timeout, REDIS_CONFIG.pool_size)
    if not ok then
        ngx.log(ngx.WARN, "failed to set redis keepalive: ", err)
    end

    -- 5. Unpack and return the results from the user function.
    return unpack(result)
end

return _M
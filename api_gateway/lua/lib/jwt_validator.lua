--
-- lib/jwt_validator.lua
-- Provides comprehensive JWT validation, including signature, claims, and revocation checks.
--

local jwt = require "resty.jwt"
local validators = require "resty.jwt-validators"
local redis_client = require "lib.redis_client"

local _M = {}

-------------------------------------------------------------------------------
-- Private Helpers & Custom Validators
-------------------------------------------------------------------------------

--- Extracts the token from an 'Authorization: Bearer <token>' header,
-- or from the 'auth_token' cookie if header is missing.
-- @return The token string, or nil and an error message.
local function extract_token()
    -- Check the Authorization header first
    local h = ngx.var.http_authorization
    if h then
        local m = h:match("^Bearer%s+(.+)$")
        if m then
            return m
        else
            return nil, "Bearer token malformed"
        end
    end

    -- Fallback: Check the 'auth_token' cookie
    local cookie_token = ngx.var.cookie_auth_token
    if cookie_token then
        return cookie_token
    else
        return nil, "Authorization header and auth_token cookie missing"
    end
end


--- Custom validator to check token expiration.
-- Sets an `X-Token-Expiring-In` header if the token is close to expiring.
-- @param exp The 'exp' claim from the token.
-- @return `true` if valid, or `false, reason` if invalid.
local function check_expiration(exp)
    local EXPIRATION_THRESHOLD = 30 -- seconds
    if type(exp) ~= "number" then
        return false, "exp claim must be a number"
    end

    local time_left = exp - ngx.time()
    if time_left <= 0 then
        return false, "token expired"
    end

    if time_left <= EXPIRATION_THRESHOLD then
        ngx.header["X-Token-Expiring-In"] = tostring(time_left)
    end
    return true
end

--- Custom validator to check if a token's JTI has been revoked via Redis.
-- @param jti The 'jti' (JWT ID) claim from the token.
-- @return `true` if not revoked, or `false, reason` if revoked.
local function check_revocation(jti)
    if type(jti) ~= "string" or jti == "" then
        return false, "jti claim is missing or invalid"
    end

    local is_revoked, err = redis_client.with_connection(function(redis_conn)
        return redis_conn:exists("revoked_jti:" .. jti)
    end)

    if err then
        ngx.log(ngx.ERR, "jti_not_revoked redis error: ", err)
        return false, "server error during jti validation"
    end
    
    if is_revoked == 1 then
        return false, "token revoked"
    end

    return true
end

--- Custom validator to ensure the user has the required 'user' role.
-- @param roles A table of roles from the JWT's 'roles' claim.
-- @return `true` if role is present, or `false, reason` if not.
local function check_user_role(roles)
    if type(roles) ~= "table" then
        return false, "roles claim missing or not a table"
    end
    for _, r in ipairs(roles) do
        if r == "user" then
            return true
        end
    end
    return false, "user role required"
end

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Verifies the integrity and validity of the JWT from the request.
-- Orchestrates signature, claim, and revocation checks.
-- @return `true, payload_table` on success.
-- @return `false, reason_string` on failure.
function _M.verify()
    -- 1. Extract the token from the request header.
    local token, err = extract_token()
    if not token then
        return false, err
    end

    -- 2. Retrieve the public key from shared memory.
    local public_pem = ngx.shared.my_keys:get("auth_pubkey")
    if not public_pem then
        ngx.log(ngx.ERR, "public key missing in shared dict")
        return false, "server configuration error"
    end

    -- 3. Verify the token signature and run all custom and standard validators.
    ---------------------------------------------------------------
    -- Claim	                Purpose	Validator 			Example
    ---------------------------------------------------------------
    -- iss	                    Token issuer	  			equals("https://auth.mycompany.com")
    -- aud	                    Intended audience			equals("my-api")
    -- sub              		Subject (usually user ID)	required()
    -- exp		                Expiration time				required()
    -- nbf		                Not valid before            required()
    -- iat	                    Issued at	                required()
    -- jti	                    Unique token ID             (for revocation) custom jti_not_revoked function
    -- Custom roles or scope	Authorization scopes/roles	custom function that checks presence of needed roles

    local res = jwt:verify(public_pem, token,
        { exp = check_expiration },
        { nbf = validators.required() },
        { iat = validators.required() },
        { sub = validators.required() },
        { jti = check_revocation },
        { roles = check_user_role }
    )

    -- 4. Return the final result.
    if not res.verified then
        return false, res.reason
    end

    return true, res.payload
end

return _M
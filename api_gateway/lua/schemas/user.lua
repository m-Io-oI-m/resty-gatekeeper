--
-- schemas/user.lua
-- Defines and validates the data structure for user login requests.
--

local compiler = require "lib.schema_compiler"

-- Defines the JSON schema for the login request body.
local schema_def = {
    type = "object",
    properties = {
        username = { type = "string", minLength = 3, maxLength = 20 },
        password = { type = "string", minLength = 6, maxLength = 50 }
    },
    required = { "username", "password" },
    additionalProperties = false
}

-- Compile the schema into a reusable validator function for performance.
local validator = compiler.compile(schema_def)

local _M = {}

--- Validates data against the compiled user schema.
-- @param data A Lua table representing the JSON object to validate.
-- @return Returns `true, nil` on success.
-- @return Returns `false, error_message` on failure.
function _M:validate(data)
    local is_valid = validator(data)

    if is_valid then
        return true, nil
    else
        return false, "Validation failed: invalid username or password format"
    end
end

return _M
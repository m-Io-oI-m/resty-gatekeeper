--
-- lib/schema_compiler.lua
-- A simple wrapper for pre-compiling JSON schemas into validation functions.
--

local jsonschema = require "jsonschema"

local _M = {}

--- Compiles a JSON schema definition into a reusable validator.
-- @param schema_def A Lua table representing the JSON schema.
-- @return A validation function.
function _M.compile(schema_def)
    local validator = jsonschema.generate_validator(schema_def)
    if not validator then
        error("Schema compilation failed. Check schema definition.")
    end
    return validator
end

return _M
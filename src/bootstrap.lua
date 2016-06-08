---- -*- Mode: Lua; -*-                                                                           
----
---- bootstrap.lua      Bootstrap Rosie by using the native Lua parser to parse rosie-core.rpl
----
---- © Copyright IBM Corporation 2016.
---- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
---- AUTHOR: Jamie A. Jennings


-- Restrict Lua's search for modules and shared objects to just the Rosie install directory
package.path = ROSIE_HOME .. "/src/?.lua"
package.cpath = ROSIE_HOME .. "/lib/?.so"

local parse = require "parse"
local syntax = require "syntax"
local compile = require "compile"
local common = require "common"
require "engine"
require "os"

if not ROSIE_HOME then error("ROSIE_HOME not set.  Exiting..."); os.exit(-1); end

----------------------------------------------------------------------------------------
-- Driver functions for RPL parser written in RPL
----------------------------------------------------------------------------------------

local function rosie_parse_without_error_check(str, pos, tokens)
   pos = pos or 1
   tokens = tokens or {}
   local nt, nextpos, state = ROSIE_ENGINE:match(str, pos)
   if (not nt) then return tokens; end
   local name, pos, text, subs = common.decode_match(nt)
   table.move(subs, 1, #subs, #tokens+1, tokens)    -- strip the 'rpl' off the top
   return rosie_parse_without_error_check(str, nextpos, tokens)
end


local function rosie_parse(str, pos, tokens)
   local astlist = rosie_parse_without_error_check(str, pos, tokens)
   local errlist = {};
   for _,a in ipairs(astlist) do
      if parse.syntax_error_check(a) then table.insert(errlist, a); end
   end
   return map(syntax.top_level_transform, astlist), errlist, astlist
end

function parse_and_explain(source)
   assert(type(source)=="string", "Compiler: source argument is not a string: "..tostring(source))
   local astlist, errlist, original_astlist = rosie_parse(source)
   if #errlist~=0 then
      local msg = "Warning: syntax error reporting is limited at this time\n"
      for _,e in ipairs(errlist) do
	 msg = msg .. parse.explain_syntax_error(e, source) .. "\n"
      end
      return false, msg
   else -- successful parse
      return astlist, original_astlist
   end
end

----------------------------------------------------------------------------------------
-- Bootstrap operations
----------------------------------------------------------------------------------------

BOOTSTRAP_COMPLETE = false;

function bootstrap()
   local vfile = io.open(ROSIE_HOME.."/VERSION")
   if not vfile then
      io.stderr:write("Installation error: File "..tostring(ROSIE_HOME).."/VERSION does not exist or is not readable\n")
      os.exit(-3)
   end
   
   -- During bootstrapping, we have to compile the rpl using the "core" compiler, and
   -- manually configure ROSIE_ENGINE without calling engine_configure.

   ROSIE_VERSION = vfile:read("l"); vfile:close();
   
   -- To bootstrap, we have to compile the Rosie rpl using the core parser/compiler

   -- Create a matching engine for processing Rosie Pattern Language files
   ROSIE_ENGINE = engine("RPL engine")
   compile.compile_core(ROSIE_HOME.."/src/rosie-core.rpl", ROSIE_ENGINE.env)
   local success, result = compile.compile_match_expression('rpl', ROSIE_ENGINE.env)
   if not success then error("Bootstrap error: could not compile rosie core rpl: " .. tostring(result)); end
   ROSIE_ENGINE.expression = 'rpl';
   ROSIE_ENGINE.pattern = success;
   ROSIE_ENGINE.encoder = "null/bootstrap";
   ROSIE_ENGINE.encoder_function = function(m) return m; end;
   -- skip the assignment below to leave the original parser in place
   if true then
      compile.parser = parse_and_explain;
   end
   BOOTSTRAP_COMPLETE = true
end

bootstrap();

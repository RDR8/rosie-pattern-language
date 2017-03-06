-- -*- Mode: Lua; -*-                                                                             
--
-- rpl-parser.lua
--
-- © Copyright IBM Corporation 2016, 2017.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings


----------------------------------------------------------------------------------------
-- Driver functions for RPL parser written in RPL
----------------------------------------------------------------------------------------

local function rosie_parse_without_error_check(rplx, str, pos, tokens)
   pos = pos or 1
   local results = {}
   local tokens, leftover = rplx:match(str, pos)
   assert(leftover==0)				    -- parser pattern ends with $
   local name, pos, text, subs = common.decode_match(tokens)
   -- strip off the "*" at the top by looking only at subs
   -- and strip the top 'rpl' off of each sub
   -- for _,token in ipairs(subs) do		    -- this loop is map_append
   --    local name, pos, text, subs = common.decode_match(token)
   --    table.move(subs, 1, #subs, #results+1, results)
   -- end
   -- return results
   return subs or {}
   
   -- pos = pos or 1
   -- tokens = tokens or {}
   -- local nt, leftover = ROSIE_RPLX:match(str, pos)
   -- if (not nt) then return tokens; end
   -- local name, pos, text, subs = common.decode_match(nt)
   -- table.move(subs, 1, #subs, #tokens+1, tokens)    -- strip the 'rpl' off the top
   -- return rosie_parse_without_error_check(str, #str-leftover+1, tokens)
end

local function rosie_parse(rplx, str, pos, tokens)
   local astlist = rosie_parse_without_error_check(rplx, str, pos, tokens)
   local errlist = {};
   for _,a in ipairs(astlist) do
      if parse.syntax_error_check(a) then table.insert(errlist, a); end
   end
   return list.map(syntax.top_level_transform, astlist), errlist, astlist
end

local function preparse(rplx_preparse, source)
   local major, minor
   local language_decl, leftover = rplx_preparse:match(source)
   if language_decl then
--      print("*** language_decl found: " .. language_decl.preparse.text)
      if parse.syntax_error_check(language_decl) then
	 return false, "Syntax error in language version declaration: " .. language_decl.preparse.text
      else
	 major = tonumber(language_decl.preparse.subs[1].version_spec.subs[1].major.text)
	 minor = tonumber(language_decl.preparse.subs[1].version_spec.subs[2].minor.text)
--	 print("    major, minor = ", major, minor)
	 return major, minor, #source-leftover+1
      end
   else
--      print("*** language_decl not found")
      return nil, nil, 1
   end
end   

local function vstr(maj, min)
   return tostring(maj) .. "." .. tostring(min)
end

function make_parse_and_explain(rplx_preparse, rplx_rpl, rpl_maj, rpl_min)
   return function(source)
	     assert(type(source)=="string", "Error: source argument is not a string: "..tostring(source))
	     -- preparse to look for rpl language version declaration
	     local major, minor, pos = preparse(rplx_preparse, source)
	     local rpl_warning
	     if major then
		if rpl_maj > major then
		   -- warn in case major version not backwards compatible
		   rpl_warning = "Warning: loading rpl at version " .. vstr(major, minor) .. " into engine at version " .. vstr(rpl_maj, rpl_min)
		elseif (rpl_maj < major) or ((rpl_maj == major) and (rpl_min < minor)) then
		   return false, "Error: loading rpl that requires version " .. vstr(major, minor) .. " but engine is at version " .. vstr(rpl_maj, rpl_min)
		end
	     end
	     local astlist, errlist, original_astlist = rosie_parse(rplx_rpl, source, pos)
	     if #errlist~=0 then
		local msg
		if rpl_warning then msg = rpl_warning .. "\n"; else msg = ""; end
		   msg = msg .. "Warning: syntax error reporting is limited at this time\n"
		for _,e in ipairs(errlist) do
		   msg = msg .. parse.explain_syntax_error(e, source) .. "\n"
		end
		return false, msg
	     else -- successful parse
		local warnings = {}
		if rpl_warning then table.insert(warnings, rpl_warning); end
		return astlist, original_astlist, warnings
	     end
	  end
end

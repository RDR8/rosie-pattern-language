-- -*- Mode: Lua; -*-                                                                             
--
-- command-common.lua
--
-- © Copyright IBM Corporation 2017.
-- LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
-- AUTHOR: Jamie A. Jennings

local p = {}

function p.set_encoder(rosie, en, name)
   local encode_fcn = rosie.encoders[name]
   if encode_fcn==nil then
      local msg = "invalid output encoder: " .. tostring(name)
      if ROSIE_DEV then error(msg)
      else io.write(msg, "\n"); os.exit(-1); end
   end
   en:output(encode_fcn)
end

function p.load_string(en, input)
   local ok, pkgname, messages = en:load(input)
   if not ok then
      if ROSIE_DEV then error(results)
	 -- TODO: change the tostring below to call an error printing procedure
      else
	 io.write("Cannot load rpl: \n", util.table_to_pretty_string(messages, false).."\n")
	 os.exit(-1)
      end
   end
   return ok, messages
end

function p.load_file(en, filename)
   local ok, pkgname, messages, actual_path = en.loadfile(en, filename)
   if not ok then
      if ROSIE_DEV then error("Cannot load file: \n" .. messages)
      else io.write("Cannot load file: \n", messages); os.exit(-1); end
   end
   return ok, messages
end


function p.setup_engine(en, args)
   -- (1a) Load whatever is specified in ~/.rosierc ???

   -- (1b) Load an rpl file
   if args.rpls then
      for _,filename in pairs(args.rpls) do
	 if args.verbose then
	    io.stdout:write("Compiling additional file ", filename, "\n")
	 end
	 -- nosearch is true so that files given on command line are not searched for
	 local success, pkgname, msg, actual_path = en.loadfile(en, filename, true)
	 if not success then
	    io.stdout:write(msg, "\n")
	    os.exit(-4)
	 end
      end
   end

   -- (1c) Load an rpl string from the command line
   if args.statements then
      for _,stm in pairs(args.statements) do
	 if args.verbose then
	    io.stdout:write(string.format("Compiling additional rpl code %q\n", stm))
	 end
	 local success, msg = p.load_string(en, stm)
	 if not success then
	    io.stdout:write(msg, "\n")
	    os.exit(-4)
	 end
      end
   end
   -- (2) Compile the expression
   local compiled_pattern
   if args.pattern then
      local expression
      if args.fixed_strings then
	 -- FUTURE: rosie.expr.literal(arg[2])
	 expression = '"' .. args.pattern:gsub('"', '\\"') .. '"'
      else
	 expression = args.pattern
      end
      if (args.command=="grep") then
	 -- FUTURE: rosie.expr.apply_macro("findall", exp)
	 if expression:sub(1,1) ~= "{" then
	    expression = "(" .. expression .. ")"
	 end
	 expression = "findall:" .. expression
      end
      local ok, msgs
      compiled_pattern, msgs = en:compile(expression)
      if not compiled_pattern then
	 table.print(msgs, false); print()	  -- FIXME (TEMPORARY)
--	 io.stdout:write(table.concat(msgs, '\n'), '\n')
	 os.exit(-4)
      end
   end
   return compiled_pattern
end

return p



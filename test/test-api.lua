---- -*- Mode: Lua; -*- 
----
---- test-api.lua
----
---- (c) 2016, Jamie A. Jennings
----

json = require "cjson"
package.loaded.api = false			    -- force re-load of api.lua

if not color_write then
   color_write = function(channel, ignore_color, ...)
		    for _,v in ipairs({...}) do
		       channel:write(v)
		    end
		 end
end

function red_write(...)
   local str = ""
   for _,v in ipairs({...}) do str = str .. tostring(v); end
   color_write(io.stdout, "red", str)
end

local count = 0
local fail_count = 0
local heading_count = 0
local subheading_count = 0
local messages = {}
local current_heading = "Heading not assigned"
local current_subheading = "Subheading not assigned"

function check(thing, message)
   count = count + 1
   heading_count = heading_count + 1
   subheading_count = subheading_count + 1
   if not (thing) then
      red_write("X")
      table.insert(messages, {h=current_heading or "Heading unassigned",
			      sh=current_subheading or "",
			      shc=subheading_count,
			      hc=heading_count,
			      c=count,
			      m=message or ""})
      fail_count = fail_count + 1
   else
      io.stdout:write(".")
   end
end

function heading(label)
   heading_count = 0
   subheading_count = 0
   current_heading = label
   current_subheading = ""
   io.stdout:write("\n", label, " ")
end

function subheading(label)
   subheading_count = 0
   current_subheading = label
   io.stdout:write("\n\t", label, " ")
end

function ending()
   io.stdout:write("\n\n** TOTAL ", tostring(count), " tests attempted.\n")
   if fail_count == 0 then
      io.stdout:write("** All tests passed.\n")
   else
      io.stdout:write("** ", tostring(fail_count), " tests failed:\n")
      for _,v in ipairs(messages) do
	 red_write(v.h, ": ", v.sh, ": ", "#", v.shc, " ", v.m, "\n")
      end
   end
end

arg_err_engine_id = "Argument error: engine id not a string"

----------------------------------------------------------------------------------------
heading("Require api")
----------------------------------------------------------------------------------------
api = require "api"

check(type(api)=="table")
check(api.VERSION)
check(type(api.VERSION=="string"))

----------------------------------------------------------------------------------------
heading("Engine")
----------------------------------------------------------------------------------------
subheading("new_engine")
check(type(api.new_engine)=="function")
ok, eid = api.new_engine("hello")
check(ok)
check(type(eid)=="string")
ok, eid2 = api.new_engine("hello")
check(ok)
check(type(eid2)=="string")
check(eid~=eid2, "engine ids (as generated by Lua) must be unique")

subheading("inspect_engine")
check(type(api.inspect_engine)=="function")
ok, name = api.inspect_engine(eid)
check(ok)
check(name=="hello")
ok, msg = api.inspect_engine()
check(not ok)
check(msg==arg_err_engine_id)
ok, msg = api.inspect_engine("foobar")
check(not ok)
check(msg=="Argument error: invalid engine id")

subheading("delete_engine")
check(type(api.delete_engine)=="function")
ok, msg = api.delete_engine(eid2)
check(ok)
check(msg=="")
ok, msg = api.delete_engine(eid2)
check(ok, "idempotent delete function")
check(msg=="")

ok, msg = api.inspect_engine(eid2)
check(not ok)
check(msg=="Argument error: invalid engine id")
check(api.inspect_engine(eid), "other engine with same name still exists")

subheading("get_env")
check(type(api.get_env)=="function")
ok, env = api.get_env(eid)
check(ok)
check(type(env)=="string", "environment is returned as a JSON string")
j = json.decode(env)
check(type(j)=="table")
check(j["."].type=="alias", "env contains built-in alias '.'")
check(j["$"].type=="alias", "env contains built-in alias '$'")
ok, msg = api.get_env()
check(not ok)
check(msg==arg_err_engine_id)
ok, msg = api.get_env("hello")
check(not ok)
check(msg=="Argument error: invalid engine id")

subheading("get_definition")
check(type(api.get_definition)=="function")
ok, msg = api.get_definition()
check(not ok)
check(msg==arg_err_engine_id)
ok, msg = api.get_definition("hello")
check(not ok)
check(msg=="Argument error: invalid engine id")
ok, def = api.get_definition(eid, "$")
check(ok, "can get a definition for '$'")
check(def=="alias $ = // built-in RPL pattern //")

----------------------------------------------------------------------------------------
heading("Load")
----------------------------------------------------------------------------------------
subheading("load_string")
check(type(api.load_string)=="function")
ok, msg = api.load_string()
check(not ok)
check(msg==arg_err_engine_id)
ok, msg = api.load_string("hello")
check(not ok)
check(msg=="Argument error: invalid engine id")
ok, msg = api.load_string(eid, "foo")
check(not ok)
check(1==msg:find("Compile error: reference to undefined identifier foo"))
ok, msg = api.load_string(eid, 'foo = "a"')
check(ok)
check(msg=="")
ok, env = api.get_env(eid)
check(ok)
j = json.decode(env)
check(j["foo"].type=="definition", "env contains newly defined identifier")
ok, msg = api.load_string(eid, 'bar = foo / "1" $')
check(ok)
check(msg=="")
ok, env = api.get_env(eid)
check(ok)
j = json.decode(env)
check(j["bar"].type=="definition", "env contains newly defined identifier")
ok, def = api.get_definition(eid, "bar")
check(def=='bar = foo / "1" $')
ok, msg = api.load_string(eid, 'x = //', "syntax error")
check(not ok)
check(1==msg:find("Syntax error at line 1: x = //"))
ok, env = api.get_env(eid)
check(ok)
j = json.decode(env)
check(not j["x"])

ok, msg = api.load_string(eid, '-- comments and \n -- whitespace\t\n\n',
   "an empty list of ast's is the result of parsing comments and whitespace")
check(ok)
check(msg=="")

g = [[grammar
  S = {"a" B} / {"b" A} / "" 
  A = {"a" S} / {"b" A A}
  B = {"b" S} / {"a" B B}
end]]

ok, msg = api.load_string(eid, g)
check(ok)
check(msg=="")

ok, def = api.get_definition(eid, "S")
check(ok)
check(1==def:find("S = grammar"))

ok, env = api.get_env(eid)
check(ok)
check(type(env)=="string", "environment is returned as a JSON string")
j = json.decode(env)
check(j["S"].type=="definition")


subheading("load_file")
check(type(api.load_file)=="function")
ok, msg = api.load_file()
check(not ok)
check(msg==arg_err_engine_id)
ok, msg = api.load_file("hello")
check(not ok)
check(msg=="Argument error: invalid engine id")

ok, msg = api.load_file(eid, "test/ok.rpl")
check(ok)
check(msg:sub(-11)=="test/ok.rpl")
ok, env = api.get_env(eid)
check(ok)
j = json.decode(env)
check(j["num"].type=="definition")
check(j["S"].type=="alias")
ok, def = api.get_definition(eid, "W")
check(ok)
check(def=="alias W = !w any")
ok, msg = api.load_file(eid, "test/undef.rpl")
check(not ok)
check(1==msg:find("Compile error: reference to undefined identifier spaces\nAt line 9:"))
ok, env = api.get_env(eid)
check(ok)
j = json.decode(env)
check(not j["badword"], "an identifier that didn't compile should not end up in the environment")
check(j["undef"], "definitions in a file prior to an error will end up in the environment... (sigh)")
check(not j["undef2"], "definitions in a file after to an error will NOT end up in the environment")
ok, msg = api.load_file(eid, "test/synerr.rpl")
check(not ok)
check(1==msg:find('Syntax error at line 8: // "abc"'))
check(msg:find('foo = "foobar" // "abc"'))

ok, msg = api.load_file(eid, "./thisfile/doesnotexist")
check(not ok)
check(msg:find("cannot open file"))
check(msg:find("./thisfile/doesnotexist"))

ok, msg = api.load_file(eid, "/etc")
check(not ok)
check(msg:find("unreadable file"))
check(msg:find("/etc"))

subheading("load_manifest")
check(type(api.load_manifest)=="function")
ok, msg = api.get_definition()
check(not ok)
check(msg==arg_err_engine_id)
ok, msg = api.get_definition("hello")
check(not ok)
check(msg=="Argument error: invalid engine id")
ok, msg = api.load_manifest(eid, "test/manifest")
check(ok)
check(msg:sub(-13)=="test/manifest")
ok, env = api.get_env(eid)
check(ok)
j = json.decode(env)
check(j["manifest_ok"].type=="definition")

ok, msg = api.load_manifest(eid, "test/manifest.err")
check(not ok)
check(1==msg:find("Compiler: cannot open file"))

ok, msg = api.load_manifest(eid, "test/manifest.synerr") -- contains a //
check(not ok)
check(1==msg:find("Compiler: unreadable file"))


----------------------------------------------------------------------------------------
heading("Match")
----------------------------------------------------------------------------------------
-- subheading("match_using_exp")
-- check(type(api.match_using_exp)=="function")
-- ok, msg = api.match_using_exp()
-- check(not ok)
-- check(msg==arg_err_engine_id)

-- ok, msg = api.match_using_exp(eid)
-- check(not ok)
-- check(msg:find("pattern expression not a string"))

-- ok, match, left = api.match_using_exp(eid, ".", "A")
-- check(ok)
-- check(left==0)
-- j = json.decode(match)
-- check(j["*"].text=="A")
-- check(j["*"].pos==1)

-- ok, match, left = api.match_using_exp(eid, '{"A".}', "ABC")
-- check(ok)
-- check(left==1)
-- j = json.decode(match)
-- check(j["*"].text=="AB")
-- check(j["*"].pos==1)

-- ok, msg = api.load_manifest(eid, "MANIFEST")
-- check(ok)

-- ok, match, left = api.match_using_exp(eid, 'common.number', "1FACE x y")
-- check(ok)
-- check(left==3)
-- j = json.decode(match)
-- check(j["common.number"].text=="1FACE")
-- check(j["common.number"].pos==1)

-- ok, match, left = api.match_using_exp(eid, '[:space:]* common.number', "   1FACE")
-- check(ok)
-- check(left==0)
-- j = json.decode(match)
-- check(j["*"].pos==1)
-- check(j["*"].subs[1]["common.number"])
-- check(j["*"].subs[1]["common.number"].pos==4)


subheading("configure")
check(type(api.configure)=="function")
ok, msg = api.configure()
check(not ok)
check(msg==arg_err_engine_id)

ok, msg = api.configure(eid)
check(not ok)
check(msg:find("configuration not a"))

ok, msg = api.configure(eid, json.encode({expression="common.dotted_identifier",
					  encoder="json"}))
check(not ok)
check(msg:find("reference to undefined identifier common.dotted_identifier"))

ok, msg = api.load_file(eid, "rpl/common.rpl")
check(ok)
ok, msg = api.configure(eid, json.encode({expression="common.dotted_identifier",
					  encoder="json"}))
check(ok)
check(msg=="")

print(" Need more tests!")

subheading("match")
check(type(api.match)=="function")
ok, msg = api.match()
check(not ok)
check(msg==arg_err_engine_id)

ok, msg = api.match(eid)
check(not ok)
check(msg:find("input text not a string"))

ok, msg = api.load_manifest(eid, "MANIFEST")
check(ok)

ok, match, left = api.match(eid, "x.y.z")
check(ok)
check(left==0)
j = json.decode(match)
check(j["common.dotted_identifier"].text=="x.y.z")
check(j["common.dotted_identifier"].subs[2]["common.identifier_plus_plus"].text=="y")

ok, msg = api.configure(eid, json.encode{expression='common.number', encoder="json"})
check(ok)

ok, match, left = api.match(eid, "x.y.z")
check(ok, "verifying that the engine exp has NOT been reset...")
check(left==0)

subheading("match_file")
check(type(api.match_file)=="function")
ok, msg = api.match_file()
check(not ok)
check(msg==arg_err_engine_id)
ok, msg = api.match_file(eid)
check(not ok)
check(msg:find(": bad input file name"))

ok, msg = api.match_file(eid, ROSIE_HOME.."/test/test-input")
check(not ok)
check(msg:find(": bad output file name"))

ok, msg = api.match_file(eid, "thisfiledoesnotexist", "", "")
check(not ok, "can't match against nonexistent file")
check(msg:find("No such file or directory"))

macosx_log1 = [[
      basic.datetime_patterns{2,2}
      common.identifier_plus_plus
      common.dotted_identifier
      "[" [:digit:]+ "]"
      "(" common.dotted_identifier {"["[:digit:]+"]"}? "):" .*
      ]]
ok, msg = api.configure(eid, json.encode{expression=macosx_log1, encoder="json"})
check(ok)			    
ok, c_in, c_out, c_err = api.match_file(eid, ROSIE_HOME.."/test/test-input", "/tmp/out", "/dev/null")
check(ok, "the macosx log pattern in the test file works on some log lines")
check(c_in==4 and c_out==2 and c_err==2, "ensure processing of first lines of test-input")

local function check_output_file()
   -- check the structure of the output file
   nextline = io.lines("/tmp/out")
   for i=1,c_out do
      local l = nextline()
      local j = json.decode(l)
      check(j["*"], "the json match in the output file is tagged with a star")
      check(j["*"].text:find("apple"), "the match in the output file is probably ok")
      local c=0
      for k,v in pairs(j["*"].subs) do c=c+1; end
      check(c==5, "the match in the output file has 5 submatches as expected")
   end   
   check(not nextline(), "only two lines of json in output file")
end

if ok then check_output_file(); end

ok, c_in, c_out, c_err = api.match_file(eid, ROSIE_HOME.."/test/test-input", "/tmp/out", "/tmp/err")
check(ok)
check(c_in==4 and c_out==2 and c_err==2, "ensure processing of error lines of test-input")

local function check_error_file()
   -- check the structure of the error file
   nextline = io.lines("/tmp/err")
   for i=1,c_err do
      local l = nextline()
      check(l:find("MUpdate"), "reading contents of error file")
   end   
   check(not nextline(), "only two lines in error file")
end

if ok then check_error_file(); check_output_file(); end

local function clear_output_and_error_files()
   local f=io.open("/tmp/out", "w")
   f:close()
   local f=io.open("/tmp/err", "w")
   f:close()
end

clear_output_and_error_files()
io.write("\nTesting output to stdout:\n")
ok, c_in, c_out, c_err = api.match_file(eid, ROSIE_HOME.."/test/test-input", "", "/tmp/err")
io.write("\nEnd of output to stdout\n")
check(ok)
--check(c_in==4 and c_out==0 and c_err==2, "ensure processing of ONLY error lines of test-input")

if ok then
   -- check that output file remains untouched
   nextline = io.lines("/tmp/out")
   check(not nextline(), "ensure output file still empty")
   check_error_file()
end

clear_output_and_error_files()
io.write("\nTesting output to stderr:\n")
ok, c_in, c_out, c_err = api.match_file(eid, ROSIE_HOME.."/test/test-input", "/tmp/out", "")
io.write("\nEnd of output to stderr\n")
check(ok)
--check(c_in==4 and c_out==2 and c_err==0, "ensure processing of ONLY matching lines of test-input")

if ok then
   -- check that error file remains untouched
   nextline = io.lines("/tmp/err")
   check(not nextline(), "ensure error file still empty")
   check_output_file()
end

subheading("eval")
check(type(api.eval)=="function")
ok, msg = api.eval()
check(not ok)
check(msg==arg_err_engine_id)
ok, msg = api.eval(eid)
check(not ok)
check(msg=="Argument error: input text not a string")

ok, msg = api.configure(eid, json.encode{expression=".*//", encoder="json"})
check(not ok)
check(msg:find('Syntax error at line 1:'))

ok, msg = api.configure(eid, json.encode{expression=".*", encoder="json"})
check(ok)
ok, match, leftover, msg = api.eval(eid, "foo")
check(ok)
check(match)
check(leftover==0)
check(msg:find('Matched "foo" %(against input "foo"%)')) -- % is esc char

ok, msg = api.configure(eid, json.encode{expression="[:digit:]", encoder="json"})
check(ok)
ok, match, leftover, msg = api.eval(eid, "foo")
check(ok)
check(not match)
check(leftover==4)
check(msg:find('FAILED to match against input "foo"')) -- % is esc char

ok, msg = api.configure(eid, json.encode{expression="[:alpha:]*", encoder="json"})
check(ok)
ok, match, leftover, msg = api.eval(eid, "foo56789")
check(ok)
check(match)
check(leftover==5)
check(msg:find('Matched "foo" %(against input "foo56789"%)')) -- % is esc char

ok, msg = api.configure(eid, json.encode{expression="common.number", encoder="json"})
check(ok)
ok, match, leftover, msg = api.eval(eid, "abc.x")
check(ok)
check(match)
j = json.decode(match)
check(j["common.hex"])
check(j["common.hex"].text=="abc")
check(leftover==2)
check(msg:find('Matched "abc" %(against input "abc.x"%)')) -- % is esc char


ending()

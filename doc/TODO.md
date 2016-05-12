# Major work items

- [ ] Expose the Rosie API as a C library; make it available through libffi.

- [ ] Add color output management to the Rosie API so any client could leverage it.
  Support CRUD on color assignments for color output. (Need to rewrite color-output.lua,
  which was a quick hack.)

- [ ] Maybe have an option to output the entire line containing a match, in
  order to make Rosie an alternative to grep.  This would be useful for
  "playing" with Rosie to understand how rpl ("rosex"?) differs from regex, and
  maybe for use in shell scripts as well.

- [ ] RPL compilation is lexically scoped in the sense that an expression is closed over the
  environment in which it is defined.  But "eval" (the interpreter function used for debugging)
  is ACCIDENTALLY dynamically scoped.  See doc/eval-scope-note.txt.

- [ ] Use syntax transformation (on ASTs) instead of current code for:
    - quantified expressions
    - tokenization ("cooked" expressions)
    - repetition syntax with one bound, e.g. {5} (meaning {5,5})

- [ ] Enhance syntax error reporting (do this AFTER the syntax transformation work is done) 

- [ ] Change the REPL to incrementally parse the input line (dispatch on the first token, then parse the rest)

- [ ] Implement post-match instructions, based on prototype work

- [ ] Enforce package namespaces, with import/export declarations

- [ ] Expose testing functionality via the API so that the user can code up a
  set of tests for their own patterns, and Rosie will run the tests and
  summarize the results.

- [ ] Support arbitrary versions and dialects of RPL with a simple declaration, e.g.
     .interpreter "rpl/0.92"
  which will load that version/dialect of RPL and use it for the (remainder of) the
  definitions in that file.  (Implementation will introduce a lexical scope to facilitate
  future addition of block structure to RPL.)

- [ ] Optimizations
    - Overall
        - Profiling
		    - If profiling suggests it would help, try LuaJIT
			- Save a compiled env so that we don't have to re-compile always
			  - Approach: de/serialize a rosie engine's environment
			  - Will luac be helpful as well?
				  luac src/run.lua 
				  lua -e "ROSIE_HOME=\"$RH\"; SCRIPTNAME=\"xyz\"" luac.out -repl
			- Tune the run-time matching loop
			- Compiler (likely but not necessarily needed)
				- Remove unnecessary assertions (which are slow in Lua)
			- Avoid multiple table indexing by assigning to a local
				- Within modules, by assigning imported values to locals
				- Within functions

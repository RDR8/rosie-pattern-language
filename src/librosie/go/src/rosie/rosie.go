//  -*- Mode: Go; -*-                                                 
// 
//  rosie.go
// 
//  © Copyright IBM Corporation 2017.
//  LICENSE: MIT License (https://opensource.org/licenses/mit-license.html)
//  AUTHOR: Jamie A. Jennings

// Package rosie contains functions for using Rosie Pattern Language
package rosie

// #cgo LDFLAGS: ${SRCDIR}/librosie.a -lm -ldl
// #include <stdlib.h>
// #include "librosie.h"
// #cgo CFLAGS: -I./include
import "C"

import "unsafe"
import "errors"
import "runtime"
import "encoding/json"

import "fmt"

type Engine struct {
 	ptr *C.struct_rosie_engine
}

type Pattern struct {
	id C.int
	engine *Engine
}

type Match struct {
	Data *string
	Leftover int
	Abend bool
	Total_time int
	Match_time int
}

type (
	Configuration [] map[string] string
	Messages [] interface{}
	RosieString = C.struct_rosie_string
)


func finalizeEngine(en *Engine) {
	C.rosie_finalize(en.ptr)
}
		
func finalizePattern(p *Pattern) {
	if p.id != 0 {
		C.rosie_free_rplx(p.engine.ptr, p.id)
		p.id = C.int(0)
	}
}


// -----------------------------------------------------------------------------
// String conversions, message decoding

// goString converts a rosie string to a go string
func goString(cstr RosieString) string {
	return C.GoStringN((*C.char)(unsafe.Pointer(cstr.ptr)), C.int(cstr.len))
}

// rosieString converts a go string to a rosie string
func rosieString(s string) RosieString {
	return C.rosie_string_from((*C.uchar)(unsafe.Pointer(C.CString(s))), C.size_t(len(s)))
}

func mungeMessages(Cmessages RosieString) (messages Messages, err error) {
	if Cmessages.ptr != nil {
		err := json.Unmarshal([]byte(goString(Cmessages)), &messages)
		if err != nil {
			return nil, err
		}
		return messages, nil
 	} 
	return nil, nil
}


// -----------------------------------------------------------------------------
// Create a rosie pattern engine

func New(name string) (en *Engine, err error) {
	var messages RosieString
	var en_ptr *C.struct_rosie_engine
	en_ptr, err = C.rosie_new(&messages)
	if en_ptr == nil {
		var printable_message string
		if messages.ptr == nil {
			printable_message = "initialization failed with an unknown error"
		} else {
			printable_message = goString(messages)
		}
		return nil, errors.New(printable_message)
	}
	engine := Engine{en_ptr}
	runtime.SetFinalizer(&engine, finalizeEngine)
	return &engine, nil
}


// -----------------------------------------------------------------------------
// Get an engine's configuration

func (en *Engine) Config() (cfg Configuration, err error) {
	var data C.struct_rosie_string
	defer C.rosie_free_string(data)
 	if ok, err := C.rosie_config(en.ptr, &data); ok != 0 {
		return nil, err
	}
	if err = json.Unmarshal([]byte(goString(data)), &cfg); err != nil {
		return nil, err
	}
	return cfg, err
}


// -----------------------------------------------------------------------------
// Compile an expression, returning a compiled pattern

func (en *Engine) Compile(exp string) (pat *Pattern, messages Messages, err error) {
 	var Cexp = rosieString(exp)
	var Cmessages RosieString
	pat = &Pattern{C.int(0), en}
	runtime.SetFinalizer(pat, finalizePattern)
	defer C.rosie_free_string(Cmessages)
	
 	if ok, err := C.rosie_compile(en.ptr, &Cexp, &pat.id, &Cmessages); ok != 0 {
		return pat, nil, err
	}
	if messages, err = mungeMessages(Cmessages); err != nil {
		pat = nil
	}
	return pat, messages, err
}


// -----------------------------------------------------------------------------
// Match an input string against a pattern

func (pat *Pattern) Match(input string, start int, encoder string) (match *Match, err error) {
	var Cmatch C.struct_rosie_matchresult
	var Cinput = rosieString(input)
	defer C.rosie_free_string(Cinput)
	var newMatch Match
	match = &newMatch
	
	ok, err := C.rosie_match(pat.engine.ptr, pat.id, C.int(1), C.CString(encoder), &Cinput, &Cmatch)
	if ok != 0 {
		return nil, err
	}

	fmt.Println("Cmatch is: ", Cmatch)
	
// TODO: Provide a convenience function that converts match data, when
// encoded in JSON, into a go map.

// TODO: Return match data as a go byte array instead of a string,
// because it may not be valid UTF-8.  (Unless this is ok in go strings?)
	

// 	if encoder == "json" {
// 		if err = json.Unmarshal([]byte(goString(Cmatch.data)), &match.data); err != nil {
// 			return nil, err
// 		}
// 	}

	if Cmatch.data.ptr == nil {
		match.Data = nil
	} else {
		data_as_string := goString(Cmatch.data)
		match.Data = &data_as_string
	}
 	match.Leftover = int(Cmatch.leftover)
 	match.Abend = (Cmatch.abend != 0)
 	match.Total_time = int(Cmatch.ttotal)
 	match.Match_time = int(Cmatch.tmatch)

	return match, nil
}



// 	var foo string = "1111111111222222222211111111112222222222111111111122222222221111111111222222222211111111112222222222"
// 	foo_string := rosieString(foo)

// 	var match C.struct_rosie_matchresult
// 	json_encoder := C.CString("json")
// 	a, err := C.rosie_match(engine, pat, 1, json_encoder, &foo_string, &match)
// 	fmt.Println(a, err, match)
// 	fmt.Println(match.leftover, goString(match.data))
// 	// retval = goString(raw_match)
// 	// fmt.Printf("Return code from match: %s\n", retval)
// //	fmt.Printf("Data|false from match: %s\n", goString(*C.string_array_ref(a,1)))
// //	fmt.Printf("Leftover chars from match: %s\n", goString(*C.string_array_ref(a,2)))

// 	// var r C.struct_rosie_stringArray
// 	// var code, js_str string
// 	// var leftover int

// 	// foo = "1239999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"
// 	// foo_string = C.rosie_new_string_ptr(C.int(len(foo)), C.CString(foo))

// 	// r = C.rosie_match(engine, foo_string, nil)
// 	// code = goString(*C.string_array_ref(r,0))
// 	// js_str = goString(*C.string_array_ref(r,1))
// 	// leftover, err = strconv.Atoi(goString(*C.string_array_ref(r,2)))
// 	// if code != "true" {
// 	// 	fmt.Printf("Error in match: %s\n", js_str)
// 	// } else {
// 	// 	fmt.Printf("Return code from match: %s\n", code)
// 	// 	fmt.Printf("Data|false from match: %s\n", js_str)
// 	// 	fmt.Printf("Leftover chars from match: %d\n", leftover)

// 	// 	var retvals map[string]map[string]interface{}
// 	// 	err = json.Unmarshal([]byte(js_str), &retvals)
// 	// 	if err != nil {
// 	// 		fmt.Println("JSON parse error:", err)
// 	// 	}
// 	// 	fmt.Printf("Match table: %s\n", retvals)
// 	// 	fmt.Printf("Text from match table: %s\n", retvals["*"]["text"])
// 	// 	fmt.Printf("Pos from match table: %d\n", int(retvals["*"]["pos"].(float64)))
// 	// 	if retvals["*"]["subs"] != nil {
// 	// 		fmt.Printf("Subs from match table: %s\n", retvals["*"]["subs"].(string))
// 	// 	} else {
// 	// 		fmt.Printf("No subs from match table.\n")
// 	// 	}
// 	// }
// 	// C.rosieL_free_stringArray(r)

// 	fmt.Printf("Exiting...\n");

// 	C.rosie_finalize(engine);


// }

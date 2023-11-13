module rpc

import json
import time

const (
	jsonrpc_version = '2.0'
)

pub type Params = map[string]string
pub type Method = fn (mut Server, Params) !Response

// pub struct Any {
// 	is_nil bool = true

// 	value_bool   bool
// 	value_string string
// 	value_float  f64

// 	value_list_bool   []bool
// 	value_list_string []string
// 	value_list_float  []f64
// 	value_list_any    []Any

// 	value      AnyType
// 	list_value AnyType
// }

// pub enum AnyType {
// 	bool
// 	string
// 	float
// 	null
// 	list
// }

// fn new_any_from_json(req string) Any {
// 	header := '"params":"'
// 	req.index(header)
// 	if req.len <= header.len + 1 {
// 		return Any{}
// 	}

// 	return Any{}
// }

[heap]
pub struct Request {
pub:
	jsonrpc string
	method  string
	params  Params
	id      string
}

pub struct Response {
pub:
	jsonrpc string         = rpc.jsonrpc_version
	result  &string        = unsafe { nil }
	error   &ResponseError = unsafe { nil }
	id      &string        = unsafe { nil }
}

pub struct ResponseError {
pub:
	code    int
	data    string
	message string
}

pub enum ErrorCodes {
	invalid_request  = -32600
	method_not_found = -32601
	invalid_params   = -32602
	internal_error   = -32603
	parse_error      = -32700
}

[heap]
pub struct Server {
pub mut:
	delay int = 100
mut:
	methods map[string]Method
	rbatch  []Request
	lbatch  []Response
	left    int
}

pub struct MethodParams {
pub:
	method string
	func   Method = unsafe { nil }
}

pub fn new_server() &Server {
	mut srv := &Server{}
	spawn srv.process_loop()
	return srv
}

pub fn (srv Server) ok(s string) Response {
	return Response{
		result: &s
	}
}

pub fn (srv Server) err(params ResponseError) Response {
	return Response{
		error: &params
	}
}

pub fn (mut srv Server) register(params MethodParams) {
	srv.methods[params.method] = params.func
}

pub fn (mut srv Server) request(req Request) {
	srv.left++
	srv.rbatch << &req
}

pub fn (mut srv Server) requests(reqs []Request) {
	srv.left += reqs.len
	srv.rbatch << reqs
}

pub fn (mut srv Server) json(req string) {
	srv.request(json.decode(Request, req) or {
		srv.requests(json.decode([]Request, req) or {
			srv.respond(
				error: &ResponseError{
					code: int(ErrorCodes.parse_error)
					message: 'Parse error'
					data: err.msg()
				}
			)
			return
		})
		return
	})
}

pub fn (mut srv Server) responses() []Response {
	mut buf := []Response{}
	for {
		buf << srv.response() or { return buf }
	}
	return buf
}

pub fn (mut srv Server) response() ?Response {
	if srv.lbatch.len < 1 {
		return none
	}
	defer {
		srv.lbatch.pop()
	}
	return srv.lbatch[srv.lbatch.len - 1]
}

fn (mut srv Server) request_pop() {
	srv.left--
	srv.rbatch.pop()
}

fn (mut srv Server) respond(resp Response) {
	srv.lbatch << resp
}

fn (mut srv Server) process_loop() {
	for {
		if srv.left == 1 {
			srv.process_request()
			continue
		}
		for srv.left > 0 {
			srv.process_request()
		}
		time.sleep(srv.delay * time.millisecond)
	}
}

[direct_array_access]
fn (mut srv Server) process_request() {
	req := srv.rbatch[srv.left - 1] or { return }
	mut failed := req.id.is_blank()
	mut msg := 'The request id is blank'
	if req.jsonrpc != rpc.jsonrpc_version {
		failed = true
		msg = 'The request version (${req.jsonrpc}) is not ${rpc.jsonrpc_version}'
	}
	if failed {
		srv.respond(
			error: &ResponseError{
				code: int(ErrorCodes.invalid_request)
				message: 'Invalid request'
				data: msg
			}
		)
		srv.request_pop()
		return
	}
	for k, v in srv.methods {
		if k != req.method {
			continue
		}
		if isnil(v) {
			srv.respond(
				error: &ResponseError{
					code: -42000
					message: 'No body'
					data: 'Requested method does not have any function body'
				}
				id: &req.id
			)
			srv.request_pop()
			continue
		}
		// res := v(new_any_from_json(json.encode(req))) or {
		res := v(mut srv, req.params) or {
			parts := err.msg().split(';;')
			srv.lbatch << Response{
				error: &ResponseError{
					code: err.code()
					message: parts[0] or { '' }
					data: parts[1] or { '' }
				}
				id: &req.id
			}
			continue
		}
		srv.respond(
			result: res.result
			id: &req.id
		)
		srv.request_pop()
		return
	}
	srv.respond(
		id: &req.id
		error: &ResponseError{
			code: int(ErrorCodes.method_not_found)
			message: 'Method not found'
			data: 'Method "${req.method}" not found!'
		}
	)
	srv.request_pop()
}

pub fn (resp Response) json() string {
	return json.encode(resp)
}

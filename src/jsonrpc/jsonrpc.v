module jsonrpc

import json
import time

const (
	jsonrpc_version  = '2.0'
	invalid_request  = -32600
	method_not_found = -32601
	method_no_body   = -32604
	invalid_params   = -32602
	internal_error   = -32603
	parse_error      = -32700
)

pub type Params = map[string]?string
type Method = fn (Params) !MethodResponse

pub fn (p Params) get(key string) ?string {
	return p[key]
}

[heap]
pub struct RPCServer {
pub:
	delay u64 // Delay in milliseconds
mut:
	waiting        bool
	methods        map[string]Method
	response_queue []Response
	request_queue  []Request
}

[heap]
pub struct Request {
pub:
	version string @[json: jsonrpc]
	method  string
	params  Params
	id      string
}

pub struct Response {
pub mut:
	version string = jsonrpc.jsonrpc_version         @[json: jsonrpc]
	result  &string        = unsafe { nil }
	error   &ResponseError = unsafe { nil }
	id      &string        = unsafe { nil }
}

pub struct ResponseError {
pub:
	code    int
	data    ?string
	message string
}

[params]
pub struct MethodResponse {
pub:
	result ?string
	error  ?ResponseError
}

pub struct MethodParams {
pub mut:
	method string
	func   Method = unsafe { nil }
}

pub fn new_rpc_server(delay u64) &RPCServer {
	mut rpc := &RPCServer{
		delay: delay
	}
	go rpc.spawn_request_queue()
	return rpc
}

fn (mut rpc RPCServer) spawn_request_queue() {
	for {
		if !rpc.waiting {
			continue
		}
		match rpc.request_queue.len {
			0 { continue }
			1 { rpc.handle_request() }
			else { rpc.handle_request_many() }
		}
		time.sleep(rpc.delay * time.millisecond)
	}
}

pub fn (mut rpc RPCServer) register(params MethodParams) {
	rpc.methods[params.method] = params.func
}

pub fn (mut rpc RPCServer) request(request Request) {
	rpc.request_queue << request
}

pub fn (mut rpc RPCServer) request_many(request []Request) {
	rpc.request_queue << request
}

pub fn (mut rpc RPCServer) request_json(request string) {
	req := json.decode(Request, request) or {
		rpc.parse_error(err)
		return
	}
	if req != Request{} {
		rpc.request(req)
		return
	}
	rpc.request_many(json.decode([]Request, request) or {
		rpc.parse_error(err)
		return
	})
}

fn (mut rpc RPCServer) parse_error(e IError) {
	rpc.response_queue << Response{
		error: &ResponseError{
			data: e.msg()
			message: 'Parse error'
			code: jsonrpc.parse_error
		}
	}
}

pub fn (mut rpc RPCServer) wait() []Response {
	rpc.waiting = true
	for {
		if rpc.response_queue.len < 1 {
			continue
		}
		rpc.waiting = false
		break
	}
	defer {
		rpc.response_queue = []Response{}
	}
	return rpc.response_queue
}

pub fn (mut rpc RPCServer) wait_json() string {
	resps := rpc.wait()
	if resps.len == 1 {
		return json.encode(resps[0])
	}
	return json.encode(resps)
}

fn (mut rpc RPCServer) handle_request() {
	req := rpc.request_queue.pop()
	rpc.response_queue << rpc.parse_request(req)
}

fn (mut rpc RPCServer) handle_request_many() {
	mut responses := []Response{}
	for req in rpc.request_queue {
		responses << rpc.parse_request(req)
	}
	rpc.request_queue = []Request{}
	rpc.response_queue << responses
}

fn (mut rpc RPCServer) parse_request(req Request) Response {
	if req.id.is_blank() {
		return rpc.err(none, message: 'Invalid request', code: jsonrpc.invalid_request)
	}
	if req.version != jsonrpc.jsonrpc_version {
		return rpc.err(req.id, message: 'Invalid version', code: jsonrpc.invalid_request)
	}
	for name, method in rpc.methods {
		if req.method != name {
			continue
		}
		if isnil(method) {
			return rpc.err(req.id,
				message: 'No method body'
				data: 'Requested method does not have a body to call'
				code: jsonrpc.method_no_body
			)
		}
		return method(req.params) or {
			return rpc.err(req.id, message: 'Method error', data: err.msg(), code: err.code())
		}.to_response(req.id)
	}
	return rpc.err(req.id,
		message: 'Method not found'
		data: 'Method "${req.method}" not found'
		code: jsonrpc.method_not_found
	)
}

fn (mut rpc RPCServer) err(id ?string, e ResponseError) Response {
	unwrapped_id := id or { unsafe {
		nil
	} }

	return Response{
		id: &unwrapped_id
		error: &e
	}
}

fn (mut rpc RPCServer) ok(id string, result ?string) Response {
	unwrapped_result := result or { unsafe {
		nil
	} }

	return Response{
		id: &id
		result: &unwrapped_result
	}
}

pub fn respond(resp MethodResponse) MethodResponse {
	return resp
}

fn (method_resp MethodResponse) to_response(id string) Response {
	mut resp := Response{
		id: &id
		version: jsonrpc.jsonrpc_version
	}
	res := method_resp.result or {
		error := method_resp.error or {
			resp.result = unsafe { nil }
			return resp
		}

		resp.error = &error
		return resp
	}

	resp.result = &res
	return resp
}

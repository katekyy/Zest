module main

import auth
import user
import jsonrpc
// import rpc.tcp
// import rpc

fn main() {
	mut rpc := jsonrpc.new_tcp_server(none, none, 500)!
	mut authsrv := auth.AuthServer{
		client_id: '43e7a021-38ba-4df5-a9ef-7cbe5594aec0'
		port: 8000
	}
	rpc.register(
		method: 'get_login_url'
		func: fn [mut authsrv] (p jsonrpc.Params) !jsonrpc.MethodResponse {
			return jsonrpc.respond(result: authsrv.init())
		}
	)
	dump(rpc.address())
	rpc.wait()!
	// 	 rpc.request_json('[{"jsonrpc":"2.0","method":"sum","params":{"0":"2", "1":"2"},"id":"0"},
	// {"jsonrpc":"2.0","method":"sum","params":{"0":"10", "1":"20"},"id":"1"}]')
	// dump(rpc.wait_json())

	// mut srv := tcp.new_server(none, none)!
	// dump(srv.address)
	// srv.register(
	// 	method: 'get_login_url'
	// 	func: fn [mut authsrv] (mut r rpc.Server, p rpc.Params) !rpc.Response {
	// 		return r.ok(authsrv.init())
	// 	}
	// )
	// srv.register(
	// 	method: 'refresh'
	// 	func: fn (mut r rpc.Server, p rpc.Params) !rpc.Response {
	// 		a := p[''] or { '' }
	// 		return r.ok(none)
	// 	}
	// )
	// srv.ok() or { println('Error: ' + err.msg()) }

	// TODO RUN THE FLUTTER/AVALONIA APP AND WAIT
}

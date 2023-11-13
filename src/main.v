module main

import auth
import user
import rpc.tcp
import rpc

fn main() {
	mut srv := tcp.new_server(none, none)!
	mut authsrv := auth.AuthServer{
		client_id: '43e7a021-38ba-4df5-a9ef-7cbe5594aec0'
		port: 8000
	}
	dump(srv.address)
	srv.register(
		method: 'get_login_url'
		func: fn [mut authsrv] (mut r rpc.Server, p rpc.Params) !rpc.Response {
			return r.ok(authsrv.init())
		}
	)
	srv.ok() or { println('Error: ' + err.msg()) }

	// srv.register(
	// 	method: 'get_user'
	// 	func: fn [usr] (_ string) !string {
	// 		return '${usr.json()}'
	// 	}
	// )
	// srv.request(rpc.Request{
	// 	method: 'get_user'
	// 	params: ''
	// 	id: '0'
	// })
	// // srv.json('{"method":"test"}')
	// for {
	// 	dump(json.encode(srv.response() or { continue }))
	// 	time.sleep(1 * time.second)
	// }

	// TODO RUN THE FLUTTER/AVALONIA APP AND WAIT
}

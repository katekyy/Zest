module tcp

import rpc
import net
import io

pub struct Server {
pub mut:
	listener &net.TcpListener
	socket   &net.TcpConn = unsafe { nil }
	server   &rpc.Server  = rpc.new_server()
	address  net.Addr
	e        &ServerError = unsafe { nil }
}

[heap]
struct ServerError {
	e IError
}

pub fn new_server(addr ?string, port ?u32) !&Server {
	listener := net.listen_tcp(.ip, addr or { '0.0.0.0' } + port or { 0 }.str())!
	mut srv := &Server{
		listener: listener
		address: listener.addr()!
	}
	spawn srv.handle_response()
	spawn srv.loop()
	return srv
}

pub fn (mut srv Server) register(params rpc.MethodParams) {
	srv.server.register(params)
}

fn (mut srv Server) loop() {
	for {
		srv.socket = srv.listener.accept() or {
			srv.e = &ServerError{err}
			// dump('a')
			return
		}
		srv.handle()
	}
}

fn (mut srv Server) handle() {
	defer {
		srv.socket.close() or { srv.e = &ServerError{err} }
	}
	// client_addr := srv.socket.peer_addr() or {
	// 	srv.e = &ServerError{err}
	// 	// dump('a')
	// 	return
	// }
	mut reader := io.new_buffered_reader(reader: srv.socket)
	defer {
		unsafe { reader.free() }
	}
	// srv.socket.write_string('')
	for {
		received := reader.read_line() or {
			// srv.e = &ServerError{err}
			// dump('a')
			return
		}
		if received.is_blank() {
			continue
		}
		srv.server.json(received)
	}
}

fn (mut srv Server) handle_response() {
	for {
		if isnil(srv.socket) {
			continue
		}
		srv.socket.write_string(srv.server.response() or { continue }.json()) or { continue }
	}
}

pub fn (mut srv Server) ok() ! {
	for {
		if isnil(srv.e) {
			continue
		}
		srv.listener.close()!
		return srv.e.e
	}
}

// pub fn

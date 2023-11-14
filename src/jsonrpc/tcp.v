module jsonrpc

import time
import net
import io

pub struct RCPTcp {
mut:
	listener &net.TcpListener
	socket   &net.TcpConn = unsafe { nil }
	address  net.Addr
	rpc      &RPCServer
	e        &ServerError = unsafe { nil }
}

[heap]
struct ServerError {
	e IError
}

pub fn new_tcp_server(addr ?string, port ?u32, delay u64) !&RCPTcp {
	listener := net.listen_tcp(.ip, addr or { '0.0.0.0' } + port or { 0 }.str())!
	mut srv := &RCPTcp{
		listener: listener
		rpc: new_rpc_server(delay)
		address: listener.addr()!
	}
	go srv.response_handler()
	go srv.request_handler()
	return srv
}

fn (mut srv RCPTcp) request_handler() {
	for {
		srv.socket = srv.listener.accept() or {
			srv.e = &ServerError{err}
			return
		}
		srv.handle_requests()
		time.sleep(srv.rpc.delay * time.millisecond)
	}
}

fn (mut srv RCPTcp) handle_requests() {
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
	// srv.socket.write_string('') or { return }
	for {
		received := reader.read_line() or { return }
		if received.is_blank() {
			continue
		}
		srv.rpc.request_json(received)
		time.sleep(srv.rpc.delay * time.millisecond)
	}
}

fn (mut srv RCPTcp) response_handler() {
	for {
		if isnil(srv.socket) {
			continue
		}
		srv.socket.write_string(srv.rpc.wait_json()) or { return }
		time.sleep(srv.rpc.delay * time.millisecond)
		// srv.socket.write_string(srv..response() or { continue }.json()) or { continue }
	}
}

pub fn (mut srv RCPTcp) wait() ! {
	for {
		if isnil(srv.e) {
			continue
		}
		srv.listener.close()!
		return srv.e.e
	}
}

pub fn (mut srv RCPTcp) register(params MethodParams) {
	srv.rpc.register(params)
}

pub fn (mut srv RCPTcp) address() net.Addr {
	return srv.address
}

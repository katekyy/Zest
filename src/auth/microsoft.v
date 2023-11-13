module auth

import vweb
import json
import net.http
import auth.pkce
import net.urllib
import crypto.aes
import crypto.hmac
import crypto.sha256

const (
	pkce_rand_string = pkce.rand_string()
	crypto_marker    = []u8{len: 8, init: 255}.bytestr()
	default_css      = '
		* {
			color: #ddd;
			background-color: #151515;
			text-align: center;
		}
		.ok {
			color: #27ae60;
		}
		.err {
			color: #d01f12;
		}
		.center {
			position: absolute;
			top: 50%;
			left: 50%;
			transform: translate(-50%, -50%);
			/*border: 0.2em solid #101010;*/
			background-color: #121212;
			/*border-radius: 0.3em;*/
			padding: 1em;
		}
		.center * {
			background-color: #121212;
		}
		h1 {
			margin: 0.3em;
		}
	'
)

pub struct AuthServer {
	vweb.Context
	code chan string @[vweb_global]
pub:
	port        int = 8080    @[vweb_global]
	client_id   string @[vweb_global]
	scope       string = 'offline_access XboxLive.signin' @[vweb_global]
	css         string = auth.default_css @[vweb_global]
	success_msg string = '<div class="center"><h1 class="ok">Done!</h1>You can close this window now.</div>' @[vweb_global]
	error_msg   string = '<p class="err">Something went wrong!</p>' @[vweb_global]
mut:
	initialized bool
}

pub fn (mut a AuthServer) listen() !MS_ACCESS_TOKEN {
	if !a.initialized {
		return error('Server not initialized before listening.')
	}
	spawn vweb.run(a, a.port)
	code := <-a.code or { return error('Code request failed! ${err}') }
	if code.is_blank() {
		return error('Code request failed! No code acquired.')
	}
	return a.exchange_code(code)!
}

pub fn (mut a AuthServer) init() string {
	challenge := pkce.sha256(auth.pkce_rand_string)
	url := 'https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize'
	payload := {
		'client_id':             a.client_id
		'response_type':         'code'
		'scope':                 a.scope
		'code_challenge':        challenge.code_challenge
		'code_challenge_method': challenge.code_challenge_method
	}
	mut query := '?'
	for key, val in payload {
		query += '&${key}=${urllib.query_escape(val)}'
	}
	a.initialized = true
	return url + query
}

['/auth'; get]
pub fn (mut a AuthServer) redirect_endpoint() vweb.Result {
	code := a.query['code'] or {
		defer {
			a.code <- ''
		}
		return a.status(400, 'Bad Request', 'No code provided!', 'err')
	}
	a.code <- code or { return a.server_error(1) }
	if code.is_blank() {
		return a.status(400, 'Bad Request', 'The provided code is blank!', 'err')
	}
	return a.css(a.success_msg)
}

pub fn (mut a AuthServer) status(code int, label string, desc string, class ?string) vweb.Result {
	a.set_status(code, label)
	return a.css('
		<div class="center">
			<h1 class=${class or { '' }}>${code}: ${label}</h1>
			<b>${desc}</b>
		</div>
	')
}

pub fn (mut a AuthServer) css(html string) vweb.Result {
	return a.html('<style>${a.css}</style> ${html}')
}

struct MS_ACCESS_TOKEN {
mut:
	access_token  string
	refresh_token string

	error             string
	error_description string
}

fn (a AuthServer) exchange_code(code string) !MS_ACCESS_TOKEN {
	resp := http.post_form('https://login.microsoftonline.com/consumers/oauth2/v2.0/token',
		{
		'client_id':     a.client_id
		'grant_type':    'authorization_code'
		'code':          code
		'scope':         a.scope
		'code_verifier': auth.pkce_rand_string
	})!
	token := json.decode(MS_ACCESS_TOKEN, resp.body) or {
		return error('Could not decode the token response!')
	}

	if resp.status_code != 200 {
		return error('Authorization issue. "${token.error}" ${token.error_description}')
	}
	if token.access_token.len < 1 {
		return error('No access token!')
	}
	return token
}

pub fn (a AuthServer) refresh_token(refresh_token string) !MS_ACCESS_TOKEN {
	resp := http.post_form('https://login.microsoftonline.com/consumers/oauth2/v2.0/token',
		{
		'client_id':     a.client_id
		'scope':         a.scope
		'refresh_token': refresh_token
		'grant_type':    'refresh_token'
	})!
	token := json.decode(MS_ACCESS_TOKEN, resp.body) or {
		return error('Could not decode the token response!')
	}

	if resp.status_code != 200 {
		return error('Authorization issue. "${token.error}" ${token.error_description}')
	}
	if token.access_token.len < 1 {
		return error('No access token!')
	}
	return token
}

pub fn (mut at MS_ACCESS_TOKEN) encrypt_refresh(passcode string) ! {
	rt := (auth.crypto_marker + at.refresh_token + auth.crypto_marker).bytes()
	aes_key := hmac.new(passcode.bytes(), []u8{}, sha256.sum, 32)
	cipher := aes.new_cipher(aes_key)

	mut buf := ''
	if rt.len % aes.block_size != 0 {
		return error('The refresh token cannot be chunked!')
	}
	for i in 0 .. int(rt.len / aes.block_size) {
		mut chunk := []u8{len: aes.block_size}
		cipher.encrypt(mut chunk, rt[aes.block_size * i..aes.block_size * (i + 1)])
		buf += chunk.bytestr()
	}
	at.refresh_token = buf
}

pub fn (mut at MS_ACCESS_TOKEN) decrypt_refresh(passcode string) ! {
	rt := at.refresh_token.bytes()
	aes_key := hmac.new(passcode.bytes(), []u8{}, sha256.sum, 32)
	cipher := aes.new_cipher(aes_key)

	mut buf := ''
	if rt.len % aes.block_size != 0 {
		return error('The refresh token cannot be chunked!')
	}
	for i in 0 .. int(rt.len / aes.block_size) {
		mut chunk := []u8{len: aes.block_size}
		cipher.decrypt(mut chunk, rt[aes.block_size * i..aes.block_size * (i + 1)])
		buf += chunk.bytestr()
	}
	if buf[0..auth.crypto_marker.len] != auth.crypto_marker
		&& buf[buf.len - auth.crypto_marker.len..] != auth.crypto_marker {
		return error('Invalid passcode! "${passcode}"')
	}
	at.refresh_token = buf.trim(auth.crypto_marker)
}

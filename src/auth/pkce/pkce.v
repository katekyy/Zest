module pkce

import crypto.sha256 as sha
import encoding.base64
import rand

pub struct PKCE {
pub:
	code_challenge        string
	code_challenge_method string
	original              string
}

pub fn sha256(raw string) PKCE {
	return PKCE{
		original: raw
		code_challenge_method: 'S256'
		code_challenge: base64.url_encode(sha.sum(raw.bytes()))
	}
}

pub fn rand_string() string {
	s := rand.u64().str() + rand.uuid_v4()
	return trim_all('-', s)
}

fn trim_all(cutset string, s string) string {
	mut buf := ''
	for ch in s {
		if ch !in cutset.bytes() {
			buf += ch.ascii_str()
		}
	}
	return buf
}

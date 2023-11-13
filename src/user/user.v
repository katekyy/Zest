module user

import net.http
import json

pub struct UserInfo {
pub:
	uuid  string @[json: id]
	name  string
	skins []Skin
	capes []Cape
pub mut:
	e Error
}

pub struct Skin {
pub:
	id      string
	state   string
	url     string
	variant string
	alias   string
}

pub struct Cape {
pub:
	id    string
	state string
	url   string
	alias string
}

pub struct Error {
pub:
	path  string
	typ   string @[json: errorType]
	error string
	msg   string @[json: errorMessage]
	dev   string @[json: developerMessage]
}

pub fn info(token string, kind string) !UserInfo {
	resp := http.fetch(
		url: 'https://api.minecraftservices.com/minecraft/profile'
		header: http.new_header_from_map({
			.authorization: '${kind} ${token}'
		})
	)!
	return from_json(resp.body)
}

pub fn (ui UserInfo) json() string {
	return json.encode(ui)
}

pub fn from_json(s string) !UserInfo {
	mut ui := json.decode(UserInfo, s)!
	if ui == UserInfo{} {
		ui.e = json.decode(Error, s)!
	}
	return ui
}

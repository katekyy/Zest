module auth

import json
import net.http

pub fn post_struct[T, Y](url string, data T, out Y) !Y {
	return json.decode(Y, http.post_json(url, json.encode(data))!.body)!
}

pub fn (mut a AuthServer) authenticate() !MC_RESP {
	ms_token := a.listen()!
	return minecraft(xsts(xbl(ms_token)!)!)!
}

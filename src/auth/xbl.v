module auth

struct XBL_REQUEST {
	properties    XBL_REQUEST_PROPERTIES @[json: Properties]
	relying_party string                 @[json: RelyingParty]
	token_type    string                 @[json: TokenType]
}

struct XBL_REQUEST_PROPERTIES {
	auth_method string @[json: AuthMethod]
	site_name   string @[json: SiteName]
	rps_ticket  string @[json: RpsTicket]
}

struct XBL_RESP {
	issue_instant  string                 @[json: IssueInstant]
	not_after      string                 @[json: NotAfter]
	token          string                 @[json: Token]
	display_claims XBL_RESP_DISPLAYCLAIMS @[json: DisplayClaims]
}

struct XBL_RESP_DISPLAYCLAIMS {
	xui []map[string]string
}

// struct XBL_RESP_DISPLAYCLAIMS_XUI {
// 	uhs string
// }

fn xbl(t MS_ACCESS_TOKEN) !XBL_RESP {
	data := XBL_REQUEST{
		properties: XBL_REQUEST_PROPERTIES{
			auth_method: 'RPS'
			site_name: 'user.auth.xboxlive.com'
			rps_ticket: 'd=${t.access_token}'
		}
		relying_party: 'http://auth.xboxlive.com'
		token_type: 'JWT'
	}
	return post_struct('https://user.auth.xboxlive.com/user/authenticate', data, XBL_RESP{})!
}

struct XSTS_REQUEST {
	properties    XSTS_REQUEST_PROPERTIES @[json: Properties]
	relying_party string                  @[json: RelyingParty]
	token_type    string                  @[json: TokenType]
}

struct XSTS_REQUEST_PROPERTIES {
	sandbox_id  string   @[json: SandboxId]
	user_tokens []string @[json: UserTokens]
}

struct XSTS_RESP {
	issue_instant  string                  @[json: IssueInstant]
	not_after      string                  @[json: NotAfter]
	token          string                  @[json: Token]
	display_claims XSTS_RESP_DISPLAYCLAMIS @[json: DisplayClaims]
}

struct XSTS_RESP_DISPLAYCLAMIS {
	xui []map[string]string
}

fn xsts(t XBL_RESP) !XSTS_RESP {
	data := XSTS_REQUEST{
		properties: XSTS_REQUEST_PROPERTIES{
			sandbox_id: 'RETAIL'
			user_tokens: [t.token]
		}
		relying_party: 'rp://api.minecraftservices.com/'
		token_type: 'JWT'
	}
	return post_struct('https://xsts.auth.xboxlive.com/xsts/authorize', data, XSTS_RESP{})!
}

pub struct MC_RESP {
pub:
	username      string
	roles         []string
	access_token  string
	token_type    string
	expires_in    int
	error_message string   @[json: errorMessage]
}

fn minecraft(t XSTS_RESP) !MC_RESP {
	resp := post_struct('https://api.minecraftservices.com/authentication/login_with_xbox',
		{
		'identityToken': 'XBL3.0 x=${t.display_claims.xui[0]['uhs']};${t.token}'
	}, MC_RESP{})!

	if !resp.error_message.is_blank() {
		dump(resp)
		return error(resp.error_message)
	}
	return resp
}

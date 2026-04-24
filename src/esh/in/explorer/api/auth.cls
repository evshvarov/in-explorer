Class esh.in.explorer.api.auth Extends %RegisteredObject
{

Parameter SessionCookieName = "inexplorer_session";

Parameter SessionPath = "/in-explorer/api/";

Parameter SessionTTLSeconds = 604800;

ClassMethod LoginWithGoogle(credential As %String = "", csrfToken As %String = "", ByRef result As %DynamicObject, ByRef httpStatus As %Integer) As %Status
{
    Set tSC = $$$OK
    Set httpStatus = 200
    Set result = ..UnauthenticatedState()

    If credential = "" {
        Set httpStatus = 400
        Quit $$$ERROR($$$GeneralError, "credential is required")
    }

    Set tSC = ..VerifyCSRFToken(csrfToken)
    If $$$ISERR(tSC) {
        Set httpStatus = 400
        Quit tSC
    }

    Set tSC = ..VerifyGoogleCredential(credential, .claims, .verifyStatus)
    If $$$ISERR(tSC) {
        Set httpStatus = verifyStatus
        Quit tSC
    }

    Set user = ..BuildUserFromClaims(claims)
    Set tSC = ..CreateSession(user, .sessionId, .expiresAt)
    If $$$ISERR(tSC) {
        Set httpStatus = 500
        Quit tSC
    }

    Do ..SetSessionCookie(sessionId, expiresAt)
    Do result.%Set("authenticated", 1)
    Do result.%Set("sessionToken", sessionId)
    Do result.%Set("user", user)
    Quit tSC
}

ClassMethod GetCurrentAuthState(ByRef result As %DynamicObject) As %Status
{
    Set result = ..UnauthenticatedState()
    Set isAuthenticated = ..GetAuthenticatedUser(.user, .sessionId, .httpStatus)
    If 'isAuthenticated {
        Quit $$$OK
    }

    Do result.%Set("authenticated", 1)
    Do result.%Set("user", user)
    Quit $$$OK
}

ClassMethod Logout(ByRef result As %DynamicObject) As %Status
{
    Set result = ..UnauthenticatedState()
    Set sessionId = ..SessionIdFromRequest()
    If sessionId '= "" {
        Kill ^ESHINEXPLORER("AuthSession", sessionId)
    }
    Do ..ClearSessionCookie()
    Quit $$$OK
}

ClassMethod GetAuthenticatedUser(ByRef user As %DynamicObject, ByRef sessionId As %String, ByRef httpStatus As %Integer) As %Boolean
{
    Set user = ""
    Set sessionId = ..SessionIdFromRequest()
    Set httpStatus = 401

    Quit:(sessionId = "") 0
    Quit:'$Data(^ESHINEXPLORER("AuthSession", sessionId)) 0

    Set expiresAt = +$Get(^ESHINEXPLORER("AuthSession", sessionId, "expiresAt"))
    If (expiresAt > 0) && (expiresAt < ..CurrentEpoch()) {
        Kill ^ESHINEXPLORER("AuthSession", sessionId)
        Do ..ClearSessionCookie()
        Quit 0
    }

    Set user = {}
    Do user.%Set("sub", $Get(^ESHINEXPLORER("AuthSession", sessionId, "sub")))
    Do user.%Set("email", ..NullableValue($Get(^ESHINEXPLORER("AuthSession", sessionId, "email"))))
    Do user.%Set("name", ..NullableValue($Get(^ESHINEXPLORER("AuthSession", sessionId, "name"))))
    Do user.%Set("picture", ..NullableValue($Get(^ESHINEXPLORER("AuthSession", sessionId, "picture"))))
    Do user.%Set("hd", ..NullableValue($Get(^ESHINEXPLORER("AuthSession", sessionId, "hd"))))
    Do user.%Set("expiresAt", expiresAt)
    Set httpStatus = 200
    Quit 1
}

ClassMethod CreateSession(user As %DynamicObject, ByRef sessionId As %String, ByRef expiresAt As %Integer) As %Status
{
    Set sessionId = $ZConvert($System.Util.CreateGUID(), "L")
    Set sessionId = $Translate(sessionId, "{}", "")
    Set expiresAt = ..CurrentEpoch() + ..SessionTTLSecondsValue()

    Kill ^ESHINEXPLORER("AuthSession", sessionId)
    Set ^ESHINEXPLORER("AuthSession", sessionId, "sub") = ..DynamicValue(user, "sub")
    Set ^ESHINEXPLORER("AuthSession", sessionId, "email") = ..DynamicValue(user, "email")
    Set ^ESHINEXPLORER("AuthSession", sessionId, "name") = ..DynamicValue(user, "name")
    Set ^ESHINEXPLORER("AuthSession", sessionId, "picture") = ..DynamicValue(user, "picture")
    Set ^ESHINEXPLORER("AuthSession", sessionId, "hd") = ..DynamicValue(user, "hd")
    Set ^ESHINEXPLORER("AuthSession", sessionId, "expiresAt") = expiresAt
    Quit $$$OK
}

ClassMethod VerifyCSRFToken(csrfToken As %String = "") As %Status
{
    Set cookieToken = ..CookieValue("g_csrf_token")
    Quit:(cookieToken = "") $$$OK
    If (csrfToken = "") || (cookieToken '= csrfToken) {
        Quit $$$ERROR($$$GeneralError, "CSRF token mismatch")
    }
    Quit $$$OK
}

ClassMethod VerifyGoogleCredential(credential As %String, ByRef claims As %DynamicObject, ByRef httpStatus As %Integer) As %Status
{
    Set claims = ""
    Set httpStatus = 500
    Set clientId = ..GoogleClientId()
    If clientId = "" {
        Quit $$$ERROR($$$GeneralError, "GOOGLE_CLIENT_ID is not configured")
    }

    Set tSC = ..LoadGoogleTokenInfo(credential, .claims, .loadStatus)
    If $$$ISERR(tSC) {
        Set httpStatus = loadStatus
        Quit tSC
    }

    Set tSC = ..ValidateGoogleClaims(claims)
    If $$$ISERR(tSC) {
        Set httpStatus = 401
        Quit tSC
    }
    Set httpStatus = 200
    Quit tSC
}

ClassMethod LoadGoogleTokenInfo(credential As %String, ByRef claims As %DynamicObject, ByRef httpStatus As %Integer) As %Status
{
    Set claims = ""
    Set httpStatus = 500
    Set url = ..GoogleTokenInfoURL()
    Set tSC = ..PrepareHttpRequest(url, .request, .location)
    If $$$ISERR(tSC) {
        Quit tSC
    }

    Set separator = "?"
    If location [ "?" {
        Set separator = "&"
    }
    Set tSC = request.Get(location _ separator _ "id_token=" _ credential)
    If $$$ISERR(tSC) {
        Quit tSC
    }

    Set response = request.HttpResponse
    If '$IsObject(response) {
        Quit $$$ERROR($$$GeneralError, "Google verification returned no response")
    }
    If +response.StatusCode '= 200 {
        Set httpStatus = 401
        Quit $$$ERROR($$$GeneralError, "Google verification failed with status "_response.StatusCode)
    }

    Set raw = ..ReadStream(response.Data)
    If raw = "" {
        Quit $$$ERROR($$$GeneralError, "Empty Google verification response")
    }

    Try {
        Set claims = {}.%FromJSON(raw)
    } Catch ex {
        Set claims = ""
    }
    If '$IsObject(claims) {
        Quit $$$ERROR($$$GeneralError, "Invalid Google verification JSON")
    }
    Quit $$$OK
}

ClassMethod PrepareHttpRequest(url As %String, ByRef request As %Net.HttpRequest, ByRef location As %String) As %Status
{
    Set request = ##class(%Net.HttpRequest).%New()
    Set location = ""
    Set scheme = ""
    Set rest = url

    If $Extract(rest, 1, 8) = "https://" {
        Set scheme = "https"
        Set rest = $Extract(rest, 9, *)
    } ElseIf $Extract(rest, 1, 7) = "http://" {
        Set scheme = "http"
        Set rest = $Extract(rest, 8, *)
    } Else {
        Quit $$$ERROR($$$GeneralError, "Unsupported token verification URL: "_url)
    }

    Set slash = $Find(rest, "/")
    If slash = 0 {
        Set request.Server = rest
        Set location = "/"
    } Else {
        Set request.Server = $Extract(rest, 1, slash - 2)
        Set location = $Extract(rest, slash - 1, *)
    }
    If scheme = "https" {
        Set request.Https = 1
        Set request.SSLConfiguration = "default"
        Set request.SSLCheckServerIdentity = 1
    }
    Quit $$$OK
}

ClassMethod ValidateGoogleClaims(claims As %DynamicObject) As %Status
{
    Set clientId = ..GoogleClientId()
    Set aud = ..DynamicValue(claims, "aud")
    If aud '= clientId {
        Quit $$$ERROR($$$GeneralError, "Google token audience mismatch")
    }

    Set iss = ..DynamicValue(claims, "iss")
    If (iss '= "accounts.google.com") && (iss '= "https://accounts.google.com") {
        Quit $$$ERROR($$$GeneralError, "Google token issuer mismatch")
    }

    Set sub = ..DynamicValue(claims, "sub")
    If sub = "" {
        Quit $$$ERROR($$$GeneralError, "Google token subject missing")
    }

    Set email = ..DynamicValue(claims, "email")
    If email = "" {
        Quit $$$ERROR($$$GeneralError, "Google token email missing")
    }

    Set verified = ..DynamicValue(claims, "email_verified")
    If (verified '= "true") && (verified '= "1") {
        Quit $$$ERROR($$$GeneralError, "Google email is not verified")
    }

    Set exp = +..DynamicValue(claims, "exp")
    If (exp > 0) && (exp < ..CurrentEpoch()) {
        Quit $$$ERROR($$$GeneralError, "Google token expired")
    }

    Set allowedEmail = ..IsAllowedEmail(email)
    Set allowedDomain = ..IsAllowedDomain(..HostedDomain(claims, email))
    If ('allowedEmail) && ('allowedDomain) {
        If ..HasAllowRestrictions() {
            Quit $$$ERROR($$$GeneralError, "Google account is not allowed")
        }
    }

    Quit $$$OK
}

ClassMethod HasAllowRestrictions() As %Boolean
{
    Quit (..AllowedEmails() '= "") || (..AllowedDomains() '= "")
}

ClassMethod IsAllowedEmail(email As %String = "") As %Boolean
{
    Quit ..ValueInList(email, ..AllowedEmails())
}

ClassMethod IsAllowedDomain(domain As %String = "") As %Boolean
{
    Quit ..ValueInList(domain, ..AllowedDomains())
}

ClassMethod ValueInList(value As %String = "", csvList As %String = "") As %Boolean
{
    Quit:(value = "") 0
    Quit:(csvList = "") 0

    Set target = $ZConvert(..Trim(value), "L")
    For index = 1:1:$Length(csvList, ",") {
        Set item = $ZConvert(..Trim($Piece(csvList, ",", index)), "L")
        If item = "" {
            Continue
        }
        If item = target {
            Quit 1
        }
    }
    Quit 0
}

ClassMethod HostedDomain(claims As %DynamicObject, email As %String = "") As %String
{
    Set hd = ..DynamicValue(claims, "hd")
    If hd '= "" {
        Quit hd
    }
    Quit $Piece(email, "@", 2)
}

ClassMethod BuildUserFromClaims(claims As %DynamicObject) As %DynamicObject
{
    Set user = {}
    Do user.%Set("sub", ..DynamicValue(claims, "sub"))
    Do user.%Set("email", ..NullableValue(..DynamicValue(claims, "email")))
    Do user.%Set("name", ..NullableValue(..DynamicValue(claims, "name")))
    Do user.%Set("picture", ..NullableValue(..DynamicValue(claims, "picture")))
    Do user.%Set("hd", ..NullableValue(..HostedDomain(claims, ..DynamicValue(claims, "email"))))
    Quit user
}

ClassMethod SetSessionCookie(sessionId As %String, expiresAt As %Integer)
{
    If '$IsObject($Get(%response)) {
        Quit
    }
    Set cookie = ..SessionCookieNameValue() _ "=" _ sessionId _ "; Path=" _ ..SessionPathValue() _ "; HttpOnly; SameSite=" _ ..SessionSameSiteValue() _ "; Max-Age=" _ (expiresAt - ..CurrentEpoch())
    If ..IsSecureRequest() {
        Set cookie = cookie _ "; Secure"
    }
    Do %response.SetHeader("Set-Cookie", cookie)
}

ClassMethod ClearSessionCookie()
{
    If '$IsObject($Get(%response)) {
        Quit
    }
    Set cookie = ..SessionCookieNameValue() _ "=; Path=" _ ..SessionPathValue() _ "; HttpOnly; SameSite=" _ ..SessionSameSiteValue() _ "; Max-Age=0"
    If ..IsSecureRequest() {
        Set cookie = cookie _ "; Secure"
    }
    Do %response.SetHeader("Set-Cookie", cookie)
}

ClassMethod IsSecureRequest() As %Boolean
{
    Quit:('$IsObject($Get(%request))) 0
    Quit:($Get(%request.CgiEnvs("HTTPS")) '= "") 1
    Quit:($Get(%request.CgiEnvs("SERVER_PORT_SECURE")) = 1) 1
    Quit 0
}

ClassMethod SessionIdFromRequest() As %String
{
    Set bearer = ..BearerTokenFromRequest()
    If bearer '= "" {
        Quit bearer
    }
    Quit ..CookieValue(..SessionCookieNameValue())
}

ClassMethod BearerTokenFromRequest() As %String
{
    Set header = $Get(%request.CgiEnvs("HTTP_AUTHORIZATION"))
    Set prefix = "Bearer "
    If header = "" {
        Quit ""
    }
    If $Extract(header, 1, $Length(prefix)) '= prefix {
        Quit ""
    }
    Quit $Extract(header, $Length(prefix) + 1, *)
}

ClassMethod CookieValue(name As %String) As %String
{
    Set cookies = $Get(%request.CgiEnvs("HTTP_COOKIE"))
    Quit:(cookies = "") ""
    Set value = ""

    For index = 1:1:$Length(cookies, ";") {
        Set pair = ..Trim($Piece(cookies, ";", index))
        Continue:(pair = "")
        If $Piece(pair, "=", 1) = name {
            Set value = $Piece(pair, "=", 2, *)
            Quit
        }
    }
    Quit value
}

ClassMethod ReadStream(stream) As %String
{
    Set raw = ""
    Quit:'$IsObject(stream) raw
    Do stream.Rewind()
    While 'stream.AtEnd {
        Set raw = raw _ stream.Read(32000)
    }
    Quit raw
}

ClassMethod UnauthenticatedState() As %DynamicObject
{
    Set result = {}
    Do result.%Set("authenticated", 0)
    Do result.%Set("user", $c(0))
    Quit result
}

ClassMethod DynamicValue(body As %DynamicObject, name As %String) As %String
{
    Quit:'$IsObject(body) ""
    Quit:'body.%IsDefined(name) ""
    Set value = body.%Get(name)
    If value = "" {
        Quit ""
    }
    If value = $c(0) {
        Quit ""
    }
    Quit value
}

ClassMethod NullableValue(value As %String = "")
{
    If value = "" {
        Quit $c(0)
    }
    Quit value
}

ClassMethod CurrentEpoch() As %Integer
{
    Set utcDays = +$Piece($ZTIMESTAMP, ",", 1)
    Set utcSeconds = +$Piece($ZTIMESTAMP, ",", 2)
    Quit ((utcDays - 47117) * 86400) + utcSeconds
}

ClassMethod Trim(value As %String = "") As %String
{
    Quit $ZStrip(value, "<>W")
}

ClassMethod Env(name As %String, defaultValue As %String = "") As %String
{
    Set value = $classmethod("%SYSTEM.Util", "GetEnviron", name)
    Quit $Select(value = "":defaultValue, 1:value)
}

ClassMethod GoogleClientId() As %String
{
    Quit ..Env("GOOGLE_CLIENT_ID")
}

ClassMethod AllowedEmails() As %String
{
    Quit ..Env("GOOGLE_ALLOWED_EMAILS")
}

ClassMethod AllowedDomains() As %String
{
    Quit ..Env("GOOGLE_ALLOWED_DOMAINS")
}

ClassMethod GoogleTokenInfoURL() As %String
{
    Quit ..Env("GOOGLE_TOKENINFO_URL", "https://oauth2.googleapis.com/tokeninfo")
}

ClassMethod SessionCookieNameValue() As %String
{
    Quit ..Env("INEXPLORER_SESSION_COOKIE", ..#SessionCookieName)
}

ClassMethod SessionPathValue() As %String
{
    Quit ..Env("INEXPLORER_SESSION_PATH", ..#SessionPath)
}

ClassMethod SessionSameSiteValue() As %String
{
    Quit ..Env("INEXPLORER_SESSION_SAMESITE", "Lax")
}

ClassMethod SessionTTLSecondsValue() As %Integer
{
    Set ttl = +..Env("INEXPLORER_SESSION_TTL_SECONDS", ..#SessionTTLSeconds)
    Quit $Select(ttl>0:ttl, 1:..#SessionTTLSeconds)
}

}

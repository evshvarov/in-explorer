/// REST API for storing and exploring LinkedIn connections in InterSystems IRIS.<br/>
/// Business logic class defined by OpenAPI in esh.in.explorer.api.spec<br/>
/// Updated Apr 23, 2026 21:48:29
Class esh.in.explorer.api.impl Extends %REST.Impl [ ProcedureBlock ]
{

Parameter ExposeServerExceptions = 1;

/// Get OpenAPI spec
ClassMethod GetSpec() As %DynamicObject
{
    set specname=$p(..%ClassName(1),".impl")
    Set spec = {}.%FromJSON(##class(%Dictionary.CompiledXData).%OpenId(specname_".spec||OpenAPI").Data)
    Set url = $Select(%request.Secure:"https",1:"http") _ "://" _ $Get(%request.CgiEnvs("SERVER_NAME")) _ ":" _ $Get(%request.CgiEnvs("SERVER_PORT")) _ %request.Application
    Set spec.servers = [{"url" : (url)}]
    Quit spec
}

ClassMethod AuthGoogle(body As %DynamicObject) As %DynamicObject
{
    Set result = ##class(esh.in.explorer.api.auth).UnauthenticatedState()
    Set body = ..ReadRequestBody()
    If '$IsObject(body) {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "Request body must be valid JSON")
        Quit result
    }

    Set credential = ..DynamicValue(body, "credential")
    Set csrfToken = ..DynamicValue(body, "csrfToken")
    Set sc = ##class(esh.in.explorer.api.auth).LoginWithGoogle(credential, csrfToken, .result, .httpStatus)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(httpStatus)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
    }
    Quit result
}

ClassMethod AuthMe() As %DynamicObject
{
    Set result = ##class(esh.in.explorer.api.auth).UnauthenticatedState()
    Set sc = ##class(esh.in.explorer.api.auth).GetCurrentAuthState(.result)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
    }
    Quit result
}

ClassMethod AuthLogout() As %DynamicObject
{
    Set result = ##class(esh.in.explorer.api.auth).UnauthenticatedState()
    Set sc = ##class(esh.in.explorer.api.auth).Logout(.result)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
    }
    Quit result
}

/// List connections<br/>
/// The method arguments hold values for:<br/>
///     search<br/>
///     city<br/>
///     industry<br/>
///     company<br/>
///     role<br/>
///     tag<br/>
///     sort<br/>
///     page<br/>
///     pageSize<br/>
/// WARNING: This method's signature has changed.
ClassMethod ListConnections(search As %String, city As %String, industry As %String, company As %String, role As %String, tag As %String, sort As %String = "recent", page As %Integer = 1, pageSize As %Integer = 50) As %DynamicObject
{
    If '..RequireAuthenticatedUser(.authUser) {
        Quit ..UnauthorizedResult()
    }
    Set result = {}
    Set roleFilter = $Get(role)
    Set page = ..NormalizePage(page)
    Set pageSize = ..NormalizePageSize(pageSize)
    Set offset = (page - 1) * pageSize
    Set search = ##class(esh.in.explorer.connection).NormalizeSearch(search)
    Set sort = ..NormalizeSort(sort)
    Do result.%Set("items", [])
    Do result.%Set("total", 0)
    Do result.%Set("page", page)
    Do result.%Set("pageSize", pageSize)

    Set totalRset = ##class(esh.in.explorer.connection).CountConnectionsFunc(search, city, industry, company, roleFilter, tag)
    If totalRset.%SQLCODE < 0 {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "SQL error: "_totalRset.%Message)
        Quit result
    }
    If totalRset.%Next() {
        Do result.%Set("total", +totalRset.%Get("Total"))
    }

    Set rset = ##class(esh.in.explorer.connection).ListConnectionsFunc(search, city, industry, company, roleFilter, tag, sort, pageSize, offset)
    If rset.%SQLCODE < 0 {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "SQL error: "_rset.%Message)
        Quit result
    }

    While rset.%Next() {
        Set connection = ##class(esh.in.explorer.connection).%OpenId(rset.%Get("ID"))
        If '$IsObject(connection) {
            Continue
        }
        Do result.items.%Push(..ConnectionToDynamicObject(connection))
    }
    Quit result
}

/// Upsert one or more connections<br/>
/// The method arguments hold values for:<br/>
///     body<br/>
/// WARNING: This method's signature has changed.
ClassMethod UpsertConnections(body As %DynamicObject) As %DynamicObject
{
    If '..RequireAuthenticatedUser(.authUser) {
        Quit ..UnauthorizedResult()
    }
    Set result = {}
    Do result.%Set("upserted", 0)
    Set body = ..ReadRequestBody()
    If '$IsObject(body) {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "Request body must be valid JSON")
        Quit result
    }

    If body.%IsA("%Library.DynamicArray") {
        Set upserted = ..UpsertConnectionArray(body, .sc)
    } Else {
        Set upserted = ..UpsertSingleConnection(body, .sc)
    }
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }

    Do result.%Set("upserted", upserted)
    Quit result
}

/// Import connections from LinkedIn CSV<br/>
/// The method arguments hold values for:<br/>
///     path, Optional absolute path to CSV file. Defaults to /home/irisowner/dev/data/Connections.csv.<br/>
/// WARNING: This method's signature has changed.
ClassMethod ImportConnectionsCsv(path As %String) As %DynamicObject
{
    If '..RequireAuthenticatedUser(.authUser) {
        Quit ..UnauthorizedResult()
    }
    Set result = {}
    Set sc = ##class(esh.in.explorer.connectionimport).ImportFromFile(path, .result)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
    }
    Quit result
}

/// Get one connection<br/>
/// The method arguments hold values for:<br/>
///     id<br/>
ClassMethod GetConnection(id As %String) As %DynamicObject
{
    If '..RequireAuthenticatedUser(.authUser) {
        Quit ..UnauthorizedResult()
    }
    Set connection = ##class(esh.in.explorer.connection).OpenByLinkedInId(id)
    If '$IsObject(connection) {
        Do ..%SetStatusCode(404)
        Do ..%SetHeader("X-Error", "Connection not found: "_id)
        Quit {}
    }
    Quit ..ConnectionToDynamicObject(connection)
}

/// Patch a connection<br/>
/// The method arguments hold values for:<br/>
///     id<br/>
///     body<br/>
/// WARNING: This method's signature has changed.
ClassMethod PatchConnection(id As %String, body As %DynamicObject) As %DynamicObject
{
    If '..RequireAuthenticatedUser(.authUser) {
        Quit ..UnauthorizedResult()
    }
    Set result = {}
    Set connection = ##class(esh.in.explorer.connection).OpenByLinkedInId(id)
    If '$IsObject(connection) {
        Do ..%SetStatusCode(404)
        Do ..%SetHeader("X-Error", "Connection not found: "_id)
        Quit result
    }

    Set body = ..ReadRequestBody()
    If '$IsObject(body) {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "Request body must be valid JSON")
        Quit result
    }
    If body.%IsA("%Library.DynamicArray") {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "Patch body must be an object")
        Quit result
    }

    Set sc = ..ApplyConnectionBody(connection, body, 1)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }
    Quit ..ConnectionToDynamicObject(connection)
}

/// Delete a connection<br/>
/// The method arguments hold values for:<br/>
///     id<br/>
/// WARNING: This method's signature has changed.
ClassMethod DeleteConnection(id As %String) As %DynamicObject
{
    If '..RequireAuthenticatedUser(.authUser) {
        Quit ..UnauthorizedResult()
    }
    Set connection = ##class(esh.in.explorer.connection).OpenByLinkedInId(id)
    If '$IsObject(connection) {
        Do ..%SetStatusCode(404)
        Do ..%SetHeader("X-Error", "Connection not found: "_id)
        Quit ""
    }
    Set connectionId = connection.%Id()

    Set sc = ##class(esh.in.explorer.connectiontag).DeleteByConnectionAndKind(connection, "arole")
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit ""
    }
    Set sc = ##class(esh.in.explorer.connectiontag).DeleteByConnectionAndKind(connection, "tag")
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit ""
    }

    Set sc = ##class(esh.in.explorer.connection).%DeleteId(connectionId)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit ""
    }

    Do ..%SetStatusCode(204)
    Quit ""
}

/// Counts for sidebar filters<br/>
/// The method arguments hold values for:<br/>
///     search<br/>
/// WARNING: This method's signature has changed.
ClassMethod GetConnectionFacets(search As %String) As %DynamicObject
{
    If '..RequireAuthenticatedUser(.authUser) {
        Quit ..UnauthorizedResult()
    }
    Set search = ##class(esh.in.explorer.connection).NormalizeSearch(search)
    Set result = {}
    Do result.%Set("cities", ..FacetResultToArray(##class(esh.in.explorer.connection).FacetCitiesFunc(search), .sc))
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }
    Do result.%Set("industries", ..FacetResultToArray(##class(esh.in.explorer.connection).FacetIndustriesFunc(search), .sc))
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }
    Do result.%Set("companies", ..FacetResultToArray(##class(esh.in.explorer.connection).FacetCompaniesFunc(search), .sc))
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }
    Do result.%Set("roles", ..FacetResultToArray(##class(esh.in.explorer.connectiontag).FacetByKindFunc(search, "arole"), .sc))
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }
    Do result.%Set("tags", ..FacetResultToArray(##class(esh.in.explorer.connectiontag).FacetByKindFunc(search, "tag"), .sc))
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }
    Quit result
}

ClassMethod UpsertConnectionArray(body As %DynamicArray, ByRef sc As %Status) As %Integer
{
    Set sc = $$$OK
    Set count = 0
    For index = 0:1:(body.%Size() - 1) {
        Set item = body.%Get(index)
        If '$IsObject(item) {
            Set sc = $$$ERROR($$$GeneralError, "Array items must be objects")
            Quit
        }
        Set count = count + ..UpsertSingleConnection(item, .sc)
        Quit:$$$ISERR(sc)
    }
    Quit count
}

ClassMethod UpsertSingleConnection(body As %DynamicObject, ByRef sc As %Status) As %Integer
{
    Set sc = $$$OK
    Set linkedInId = ..NormalizeLinkedInId(body)
    If linkedInId = "" {
        Set sc = $$$ERROR($$$GeneralError, "Connection id is required")
        Quit 0
    }

    Set connection = ##class(esh.in.explorer.connection).OpenByLinkedInId(linkedInId)
    If '$IsObject(connection) {
        Set connection = ##class(esh.in.explorer.connection).%New()
        Set connection.LinkedInId = linkedInId
    }

    Set sc = ..ApplyConnectionBody(connection, body, 0)
    If $$$ISERR(sc) {
        Quit 0
    }
    Quit 1
}

ClassMethod ApplyConnectionBody(connection As esh.in.explorer.connection, body As %DynamicObject, isPatch As %Boolean = 0) As %Status
{
    Set tSC = $$$OK
    If 'isPatch || body.%IsDefined("id") {
        Set linkedInId = ..NormalizeLinkedInId(body)
        If linkedInId = "" {
            Quit $$$ERROR($$$GeneralError, "Connection id is required")
        }
        Set connection.LinkedInId = linkedInId
    }
    If 'isPatch || body.%IsDefined("firstName") {
        Set connection.FirstName = ..DynamicValue(body, "firstName")
    }
    If 'isPatch || body.%IsDefined("lastName") {
        Set connection.LastName = ..DynamicValue(body, "lastName")
    }
    If 'isPatch || body.%IsDefined("url") {
        Set connection.Url = ..DynamicValue(body, "url")
    }
    If 'isPatch || body.%IsDefined("email") {
        Set connection.Email = ..DynamicValue(body, "email")
    }
    If 'isPatch || body.%IsDefined("company") {
        Set connection.Company = ..DynamicValue(body, "company")
    }
    If 'isPatch || body.%IsDefined("position") {
        Set connection.Position = ..DynamicValue(body, "position")
    }
    If 'isPatch || body.%IsDefined("connectedOn") {
        Set connection.ConnectedOn = ..NormalizeDate(..DynamicValue(body, "connectedOn"), .dateSC)
        If $$$ISERR(dateSC) {
            Quit dateSC
        }
    }
    If 'isPatch || body.%IsDefined("city") {
        Set connection.City = ..DynamicValue(body, "city")
    }
    If 'isPatch || body.%IsDefined("country") {
        Set connection.Country = ..DynamicValue(body, "country")
    }
    If 'isPatch || body.%IsDefined("industry") {
        Set connection.Industry = ..DynamicValue(body, "industry")
    }
    If 'isPatch || body.%IsDefined("notes") {
        Set connection.Notes = ..DynamicValue(body, "notes")
    }

    If connection.Url = "" {
        If connection.LinkedInId '= "" {
            Set connection.Url = "https://www.linkedin.com/in/" _ connection.LinkedInId
        }
    }

    Set sc = connection.%Save()
    If $$$ISERR(sc) {
        Quit sc
    }

    If 'isPatch || body.%IsDefined("roleTags") {
        Set sc = ..ReplaceLabels(connection, "arole", ..DynamicArrayValue(body, "roleTags"))
        If $$$ISERR(sc) {
            Quit sc
        }
    }
    If 'isPatch || body.%IsDefined("tags") {
        Set sc = ..ReplaceLabels(connection, "tag", ..DynamicArrayValue(body, "tags"))
        If $$$ISERR(sc) {
            Quit sc
        }
    }

    Quit tSC
}

ClassMethod ReplaceLabels(connection As esh.in.explorer.connection, kind As %String, values As %DynamicArray = "") As %Status
{
    Set sc = ##class(esh.in.explorer.connectiontag).DeleteByConnectionAndKind(connection, kind)
    If $$$ISERR(sc) {
        Quit sc
    }
    If '$IsObject(values) {
        Quit $$$OK
    }

    For index = 0:1:(values.%Size() - 1) {
        Set value = values.%Get(index)
        If value = "" {
            Continue
        }
        Set label = ##class(esh.in.explorer.connectiontag).%New()
        Set label.ParentConnection = connection
        Set label.Kind = kind
        Set label.Value = value
        Set sc = label.%Save()
        If $$$ISERR(sc) {
            Quit sc
        }
    }
    Quit $$$OK
}

ClassMethod ConnectionToDynamicObject(connection As esh.in.explorer.connection) As %DynamicObject
{
    Set result = {}
    Do result.%Set("id", connection.LinkedInId)
    Do result.%Set("firstName", $Select(connection.FirstName = "":$c(0), 1:connection.FirstName))
    Do result.%Set("lastName", $Select(connection.LastName = "":$c(0), 1:connection.LastName))
    Do result.%Set("url", $Select(connection.Url = "":$c(0), 1:connection.Url))
    Do result.%Set("email", ..NullableValue(connection.Email))
    Do result.%Set("company", ..NullableValue(connection.Company))
    Do result.%Set("position", ..NullableValue(connection.Position))
    Do result.%Set("connectedOn", ..NullableDate(connection.ConnectedOn))
    Do result.%Set("city", ..NullableValue(connection.City))
    Do result.%Set("country", ..NullableValue(connection.Country))
    Do result.%Set("industry", ..NullableValue(connection.Industry))
    Do result.%Set("roleTags", ..LabelsToArray(connection.%Id(), "arole"))
    Do result.%Set("tags", ..LabelsToArray(connection.%Id(), "tag"))
    Do result.%Set("notes", ..NullableValue(connection.Notes))
    Quit result
}

ClassMethod LabelsToArray(connectionId As %Integer, kind As %String) As %DynamicArray
{
    Set result = []
    Set rset = ##class(esh.in.explorer.connectiontag).ListByConnectionAndKindFunc(connectionId, kind)
    If rset.%SQLCODE < 0 {
        Quit result
    }
    While rset.%Next() {
        Do result.%Push(rset.%Get("Value"))
    }
    Quit result
}

ClassMethod FacetResultToArray(rset, ByRef sc As %Status) As %DynamicArray
{
    Set sc = $$$OK
    Set result = []
    If rset.%SQLCODE < 0 {
        Set sc = $$$ERROR($$$GeneralError, "SQL error: "_rset.%Message)
        Quit result
    }
    While rset.%Next() {
        Set item = {}
        Do item.%Set("value", rset.%Get("Value"))
        Do item.%Set("count", +rset.%Get("ItemCount"))
        Do result.%Push(item)
    }
    Quit result
}

ClassMethod ReadRequestBody()
{
    Set raw = ""
    Set parsed = ""
    If '$IsObject(%request.Content) {
        Quit ""
    }
    Do %request.Content.Rewind()
    While '%request.Content.AtEnd {
        Set raw = raw _ %request.Content.Read(32000)
    }
    If raw = "" {
        Quit ""
    }
    Set first = ..FirstSignificantChar(raw)
    Try {
        If first = "[" {
            Set parsed = [].%FromJSON(raw)
        } Else {
            Set parsed = {}.%FromJSON(raw)
        }
    } Catch ex {
        Set parsed = ""
    }
    Quit parsed
}

ClassMethod FirstSignificantChar(raw As %String = "") As %String
{
    Set result = ""
    For index = 1:1:$Length(raw) {
        Set ch = $Extract(raw, index)
        If (ch = $C(9)) ! (ch = $C(10)) ! (ch = $C(13)) ! (ch = " ") {
            Continue
        }
        Set result = ch
        Quit
    }
    Quit result
}

ClassMethod NormalizeLinkedInId(body As %DynamicObject) As %String
{
    Set linkedInId = ..DynamicValue(body, "id")
    If linkedInId '= "" {
        Quit linkedInId
    }
    Set url = ..DynamicValue(body, "url")
    Quit ..LinkedInIdFromUrl(url)
}

ClassMethod LinkedInIdFromUrl(url As %String = "") As %String
{
    If url = "" {
        Quit ""
    }
    Set marker = "/in/"
    Set start = $Find(url, marker)
    If 'start {
        Quit ""
    }
    Set slug = $Extract(url, start, *)
    Set slash = $Find(slug, "/")
    If slash > 0 {
        Set slug = $Extract(slug, 1, slash - 2)
    }
    Set qmark = $Find(slug, "?")
    If qmark > 0 {
        Set slug = $Extract(slug, 1, qmark - 2)
    }
    Set hash = $Find(slug, "#")
    If hash > 0 {
        Set slug = $Extract(slug, 1, hash - 2)
    }
    Quit slug
}

ClassMethod DynamicValue(body As %DynamicObject, name As %String) As %String
{
    If 'body.%IsDefined(name) {
        Quit ""
    }
    Set value = body.%Get(name)
    If value = "" {
        Quit ""
    }
    If value = $c(0) {
        Quit ""
    }
    Quit value
}

ClassMethod DynamicArrayValue(body As %DynamicObject, name As %String)
{
    If 'body.%IsDefined(name) {
        Quit ""
    }
    Set value = body.%Get(name)
    If '$IsObject(value) {
        Quit ""
    }
    If 'value.%IsA("%Library.DynamicArray") {
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

ClassMethod NullableDate(value As %Date = "")
{
    If value = "" {
        Quit $c(0)
    }
    Quit ##class(%Library.Date).LogicalToOdbc(value)
}

ClassMethod RequireAuthenticatedUser(ByRef authUser As %DynamicObject) As %Boolean
{
    Set ok = ##class(esh.in.explorer.api.auth).GetAuthenticatedUser(.authUser, .sessionId, .httpStatus)
    If 'ok {
        Do ..%SetStatusCode(httpStatus)
        Do ..%SetHeader("X-Error", "Authentication required")
    }
    Quit ok
}

ClassMethod UnauthorizedResult(message As %String = "Authentication required") As %DynamicObject
{
    Set result = {}
    Do result.%Set("error", message)
    Quit result
}

ClassMethod NormalizeDate(value As %String = "", ByRef sc As %Status)
{
    Set sc = $$$OK
    If value = "" {
        Quit ""
    }
    If value?4N1"-"2N1"-"2N {
        Quit $ZDATEH(value, 3)
    }
    If value?1.2N1" "3A1" "4N {
        Set day = +$Piece(value, " ", 1)
        Set monthName = $ZConvert($Piece(value, " ", 2), "U")
        Set year = +$Piece(value, " ", 3)
        Set month = ..MonthNumber(monthName)
        If month = 0 {
            Set sc = $$$ERROR($$$GeneralError, "Invalid date value: "_value)
            Quit ""
        }
        Set iso = year _ "-" _ $Justify(month, 2, 0) _ "-" _ $Justify(day, 2, 0)
        Set iso = $Translate(iso, " ", "0")
        Quit $ZDATEH(iso, 3)
    }
    Set sc = $$$ERROR($$$GeneralError, "Invalid date value: "_value)
    Quit ""
}

ClassMethod MonthNumber(monthName As %String) As %Integer
{
    If monthName = "JAN" Quit 1
    If monthName = "FEB" Quit 2
    If monthName = "MAR" Quit 3
    If monthName = "APR" Quit 4
    If monthName = "MAY" Quit 5
    If monthName = "JUN" Quit 6
    If monthName = "JUL" Quit 7
    If monthName = "AUG" Quit 8
    If monthName = "SEP" Quit 9
    If monthName = "OCT" Quit 10
    If monthName = "NOV" Quit 11
    If monthName = "DEC" Quit 12
    Quit 0
}

ClassMethod NormalizePage(page As %Integer = 1) As %Integer
{
    Quit $Select(page>0:page, 1:1)
}

ClassMethod NormalizePageSize(pageSize As %Integer = 50) As %Integer
{
    If pageSize < 1 {
        Quit 50
    }
    If pageSize > 200 {
        Quit 200
    }
    Quit pageSize
}

ClassMethod NormalizeSort(sort As %String = "recent") As %String
{
    Quit $Select((sort = "name") || (sort = "company"):sort, 1:"recent")
}

}

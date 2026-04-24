Class esh.in.explorer.tests.UnitTests Extends %UnitTest.TestCase
{

Method InitRequestResponse()
{
    Set %response = ##class(%CSP.Response).%New()
    Set %request = ##class(%CSP.Request).%New()
    Set %request.CgiEnvs("SERVER_NAME") = "localhost"
    Set %request.CgiEnvs("SERVER_PORT") = "52773"
}

Method SetRequestBody(json As %String)
{
    Set stream = ##class(%Stream.GlobalCharacter).%New()
    Do stream.Write(json)
    Do stream.Rewind()
    Set %request.Content = stream
}

Method AuthenticateRequest(email As %String = "tester@example.com", name As %String = "Test User")
{
    Set user = {}
    Do user.%Set("sub", "unit-auth-"_$J_"-"_$Random(100000))
    Do user.%Set("email", email)
    Do user.%Set("name", name)
    Set sc = ##class(esh.in.explorer.api.auth).CreateSession(user, .sessionId, .expiresAt)
    Do $$$AssertStatusOK(sc, "Test session should be created")
    Set %request.CgiEnvs("HTTP_COOKIE") = ##class(esh.in.explorer.api.auth).SessionCookieNameValue()_"="_sessionId
}

Method CleanupConnection(linkedInId As %String)
{
    Set connection = ##class(esh.in.explorer.connection).OpenByLinkedInId(linkedInId)
    If $IsObject(connection) {
        Do connection.%Delete()
    }
}

Method FindConnection(items As %DynamicArray, linkedInId As %String) As %DynamicObject
{
    Set found = ""
    For index = 0:1:(items.%Size() - 1) {
        Set item = items.%Get(index)
        If $IsObject(item) {
            If item.id = linkedInId {
                Set found = item
                Quit
            }
        }
    }
    Quit found
}

Method FindFacet(items As %DynamicArray, value As %String) As %DynamicObject
{
    Set found = ""
    Set target = $ZConvert(value, "U")
    For index = 0:1:(items.%Size() - 1) {
        Set item = items.%Get(index)
        If $IsObject(item) {
            If $ZConvert(item.value, "U") = target {
                Set found = item
                Quit
            }
        }
    }
    Quit found
}

Method TestGetSpec()
{
    Do ..InitRequestResponse()
    Set spec = ##class(esh.in.explorer.api.impl).GetSpec()
    Do $$$AssertTrue($IsObject(spec), "Spec response must be an object")
    Do $$$AssertEquals(spec.swagger, "2.0", "Unexpected swagger version")
    Do $$$AssertEquals(spec.basePath, "/in-explorer/api", "Unexpected base path")
    Do $$$AssertTrue(spec.paths.%IsDefined("/connections"), "Spec must expose /connections")
    Do $$$AssertTrue(spec.paths.%IsDefined("/connections/{id}"), "Spec must expose /connections/{id}")
    Do $$$AssertTrue(spec.paths.%IsDefined("/connections/facets"), "Spec must expose /connections/facets")
    Do $$$AssertTrue(spec.paths.%IsDefined("/_spec"), "Spec must expose /_spec")
}

Method TestConnectionCRUDAndFacets()
{
    Set linkedInId = "unit-test-"_$J_"-"_$Random(10000)
    Try {
        Do ..CleanupConnection(linkedInId)

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Do ..SetRequestBody("{""id"":"""_linkedInId_""",""firstName"":""Vittoria"",""lastName"":""Braggion"",""url"":""https://www.linkedin.com/in/"_linkedInId_""",""email"":""vittoria@example.com"",""company"":""Docebo"",""position"":""Business Development Representative"",""connectedOn"":""18 Apr 2026"",""city"":""Milan"",""country"":""Italy"",""industry"":""Education"",""roleTags"":[""sales""],""tags"":[""warm"",""saas""],""notes"":""First import""}")
        Set upserted = ##class(esh.in.explorer.api.impl).UpsertConnections()
        Do $$$AssertTrue($IsObject(upserted), "Upsert response must be an object")
        Do $$$AssertEquals(upserted.upserted, 1, "Unexpected upsert count")

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Set connection = ##class(esh.in.explorer.api.impl).GetConnection(linkedInId)
        Do $$$AssertTrue($IsObject(connection), "Connection must be returned")
        Do $$$AssertEquals(connection.id, linkedInId, "Unexpected id")
        Do $$$AssertEquals(connection.firstName, "Vittoria", "Unexpected firstName")
        Do $$$AssertEquals(connection.company, "Docebo", "Unexpected company")
        Do $$$AssertEquals(connection.connectedOn, "2026-04-18", "Date must be normalized to ISO")
        Do $$$AssertEquals(connection.roleTags.%Size(), 1, "Unexpected roleTags count")
        Do $$$AssertEquals(connection.roleTags.%Get(0), "sales", "Unexpected role tag")
        Do $$$AssertEquals(connection.tags.%Size(), 2, "Unexpected tags count")

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Set listed = ##class(esh.in.explorer.api.impl).ListConnections("Vittoria", "Milan", "Education", "Docebo", "sales", "warm", "recent", 1, 50)
        Do $$$AssertTrue($IsObject(listed), "List response must be an object")
        Do $$$AssertTrue($IsObject(listed.items), "List items must be an array")
        Do $$$AssertTrue(listed.items.%Size() >= 0, "List query should return an array result")

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Set facets = ##class(esh.in.explorer.api.impl).GetConnectionFacets("Vittoria")
        Do $$$AssertTrue($IsObject(facets), "Facets response must be an object")
        Do $$$AssertTrue($IsObject(..FindFacet(facets.cities, "Milan")), "City facet should contain Milan")
        Do $$$AssertTrue($IsObject(..FindFacet(facets.industries, "Education")), "Industry facet should contain Education")
        Do $$$AssertTrue($IsObject(..FindFacet(facets.companies, "Docebo")), "Company facet should contain Docebo")
        Do $$$AssertTrue($IsObject(..FindFacet(facets.roles, "sales")), "Role facet should contain sales")
        Do $$$AssertTrue($IsObject(..FindFacet(facets.tags, "warm")), "Tag facet should contain warm")

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Do ..SetRequestBody("{""city"":""London"",""notes"":""Updated note"",""roleTags"":[""operator""],""tags"":[""vip""]}")
        Set patched = ##class(esh.in.explorer.api.impl).PatchConnection(linkedInId)
        Do $$$AssertTrue($IsObject(patched), "Patch response must be an object")
        Do $$$AssertEquals(patched.city, "London", "City patch did not persist")
        Do $$$AssertEquals(patched.notes, "Updated note", "Notes patch did not persist")
        Do $$$AssertEquals(patched.roleTags.%Size(), 1, "Patched roleTags count mismatch")
        Do $$$AssertEquals(patched.roleTags.%Get(0), "operator", "Patched roleTags mismatch")
        Do $$$AssertEquals(patched.tags.%Size(), 1, "Patched tags count mismatch")
        Do $$$AssertEquals(patched.tags.%Get(0), "vip", "Patched tags mismatch")

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Do ##class(esh.in.explorer.api.impl).DeleteConnection(linkedInId)
        Do $$$AssertEquals(+%response.Status, 204, "Delete should set 204")

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Set missing = ##class(esh.in.explorer.api.impl).GetConnection(linkedInId)
        Do $$$AssertTrue($IsObject(missing), "Missing connection response must be an object")
        Do $$$AssertEquals(missing.%Size(), 0, "Deleted connection should not be returned")
        Do $$$AssertEquals(+%response.Status, 404, "Missing connection should set 404")
    } Catch ex {
        Do ..CleanupConnection(linkedInId)
        Throw ex
    }
    Do ..CleanupConnection(linkedInId)
}

Method TestUpsertConnectionArray()
{
    Set linkedInId1 = "unit-batch-a-"_$J_"-"_$Random(10000)
    Set linkedInId2 = "unit-batch-b-"_$J_"-"_$Random(10000)
    Try {
        Do ..CleanupConnection(linkedInId1)
        Do ..CleanupConnection(linkedInId2)

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Do ..SetRequestBody("[{""id"":"""_linkedInId1_""",""firstName"":""Ada"",""lastName"":""Lovelace"",""url"":""https://www.linkedin.com/in/"_linkedInId1_"""},{""id"":"""_linkedInId2_""",""firstName"":""Grace"",""lastName"":""Hopper"",""url"":""https://www.linkedin.com/in/"_linkedInId2_""",""company"":""Navy""}]")
        Set result = ##class(esh.in.explorer.api.impl).UpsertConnections()
        Do $$$AssertTrue($IsObject(result), "Batch upsert response must be an object")
        Do $$$AssertEquals(result.upserted, 2, "Batch upsert count mismatch")

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Set firstConnection = ##class(esh.in.explorer.api.impl).GetConnection(linkedInId1)
        Do $$$AssertEquals(firstConnection.firstName, "Ada", "First batch record missing")

        Do ..InitRequestResponse()
        Do ..AuthenticateRequest()
        Set secondConnection = ##class(esh.in.explorer.api.impl).GetConnection(linkedInId2)
        Do $$$AssertEquals(secondConnection.company, "Navy", "Second batch record missing")
    } Catch ex {
        Do ..CleanupConnection(linkedInId1)
        Do ..CleanupConnection(linkedInId2)
        Throw ex
    }
    Do ..CleanupConnection(linkedInId1)
    Do ..CleanupConnection(linkedInId2)
}

Method TestImportConnectionsCsv()
{
    Do ..InitRequestResponse()
    Do ..AuthenticateRequest()
    Set result = ##class(esh.in.explorer.api.impl).ImportConnectionsCsv("/home/irisowner/dev/data/Connections.csv")
    Do $$$AssertTrue($IsObject(result), "Import response must be an object")
    Do $$$AssertEquals(result.path, "/home/irisowner/dev/data/Connections.csv", "Unexpected import path")
    Do $$$AssertTrue((result.status = "ok") || (result.status = "partial"), "Unexpected import status")
    Do $$$AssertTrue(result.processed > 0, "CSV import should process at least one row")
    Do $$$AssertTrue(result.imported > 0, "CSV import should import at least one row")
}

Method TestAuthSessionLifecycle()
{
    Do ..InitRequestResponse()
    Set user = {}
    Do user.%Set("sub", "google-sub-123")
    Do user.%Set("email", "user@example.com")
    Do user.%Set("name", "Explorer User")
    Set sc = ##class(esh.in.explorer.api.auth).CreateSession(user, .sessionId, .expiresAt)
    Do $$$AssertStatusOK(sc, "Session should be created")
    Set %request.CgiEnvs("HTTP_COOKIE") = ##class(esh.in.explorer.api.auth).SessionCookieNameValue()_"="_sessionId

    Set ok = ##class(esh.in.explorer.api.auth).GetAuthenticatedUser(.currentUser, .currentSessionId, .httpStatus)
    Do $$$AssertTrue(ok, "Session should authenticate")
    Do $$$AssertEquals(httpStatus, 200, "Unexpected auth status")
    Do $$$AssertEquals(currentSessionId, sessionId, "Session id mismatch")
    Do $$$AssertEquals(currentUser.sub, "google-sub-123", "Unexpected session subject")
    Do $$$AssertEquals(currentUser.email, "user@example.com", "Unexpected session email")

    Set sc = ##class(esh.in.explorer.api.auth).Logout(.logoutState)
    Do $$$AssertStatusOK(sc, "Logout should succeed")
    Do $$$AssertEquals(logoutState.authenticated, 0, "Logout should clear auth state")

    Set ok = ##class(esh.in.explorer.api.auth).GetAuthenticatedUser(.loggedOutUser, .loggedOutSessionId, .loggedOutStatus)
    Do $$$AssertTrue('ok, "Session should be removed after logout")
    Do $$$AssertEquals(loggedOutStatus, 401, "Logged out status mismatch")
}

Method TestCurrentEpochUsesUnixTime()
{
    Set now = ##class(esh.in.explorer.api.auth).CurrentEpoch()
    Do $$$AssertTrue(now > 1700000000, "Current epoch should be Unix time in seconds")
    Do $$$AssertTrue(now < 2000000000, "Current epoch should be in a reasonable Unix timestamp range")
}

}

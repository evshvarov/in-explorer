Class esh.iris.entity.api.security Extends %RegisteredObject
{

Parameter webapp = "/in-explorer/api";

ClassMethod SetupSecurity() As %Status
{
    Set tSC = $$$OK
    Set sc = ..IntroduceSQLARole()
    If $$$ISERR(sc) {
        Set tSC = sc
    }
    Set sc = ..AddARole()
    If $$$ISERR(sc) {
        Set tSC = sc
    }
    Set sc = ..AddCORS()
    If $$$ISERR(sc) {
        Set tSC = sc
    }
    Quit tSC
}

ClassMethod IntroduceSQLARole() As %Status
{
    Set namespace = $Namespace
    &SQL(CREATE ROLE irisentityapi)
    If (SQLCODE '= 0) && (SQLCODE '= -100) && (SQLCODE '= -118) {
        Quit $$$ERROR($$$GeneralError, "Error creating role: "_SQLCODE)
    }

    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    Set sc = ##class(Security.Roles).Get("irisentityapi", .properties)
    If $$$ISERR(sc) {
        Quit $$$ERROR($$$GeneralError, "Error reading irisentityapi role: "_sc)
    }
    If ("," _ $Get(properties("Resources")) _ ",") '[ ",%DB_USER:R," {
        Set $Piece(properties("Resources"), ",", *) = "%DB_USER:R"
    }
    Set sc = ##class(Security.Roles).Modify("irisentityapi", .properties)
    If $$$ISERR(sc) {
        Quit $$$ERROR($$$GeneralError, "Error modifying irisentityapi role: "_sc)
    }
    Set $NAMESPACE=namespace

    &SQL(GRANT SELECT ON %Dictionary.CompiledClass TO irisentityapi)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting %Dictionary.CompiledClass privileges: "_SQLCODE)
    }

    &SQL(GRANT SELECT ON %Dictionary.CompiledProperty TO irisentityapi)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting %Dictionary.CompiledProperty privileges: "_SQLCODE)
    }

    &SQL(GRANT SELECT ON INFORMATION_SCHEMA.SCHEMATA TO irisentityapi)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting INFORMATION_SCHEMA.SCHEMATA privileges: "_SQLCODE)
    }

    &SQL(GRANT SELECT ON INFORMATION_SCHEMA.TABLES TO irisentityapi)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting INFORMATION_SCHEMA.TABLES privileges: "_SQLCODE)
    }

    &SQL(GRANT SELECT ON INFORMATION_SCHEMA.COLUMNS TO irisentityapi)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting INFORMATION_SCHEMA.COLUMNS privileges: "_SQLCODE)
    }

    Quit $$$OK
}

ClassMethod AddARole(appname = "", appARole = "irisentityapi") As %Status
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"

    If appname = "" {
        Set appname = ..#webapp
    }
    Set status = ##class(Security.Applications).Get(appname, .appProps)
    If $$$ISERR(status) {
        Quit status
    }
    If (":" _ $Get(appProps("MatchRoles")) _ ":") '[ (":" _ appARole _ ":") {
        Set appProps("MatchRoles") = $Get(appProps("MatchRoles")) _ ":" _ appARole
    }
    Set status = ##class(Security.Applications).Modify(appname, .appProps)
    Quit status
}

ClassMethod AddCORS(appname = "") As %Status
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"

    If appname = "" {
        Set appname = ..#webapp
    }
    Set status = ##class(Security.Applications).Get(appname, .appProps)
    If $$$ISERR(status) {
        Quit status
    }
    Set appProps("CorsAllowlist") = "*"
    Set appProps("CorsCredentialsAllowed") = 1
    Set appProps("CorsHeadersList") = "Content-Type,Authorization,Accept-Language,X-Requested-With,session"
    Set status = ##class(Security.Applications).Modify(appname, .appProps)
    Quit status
}

}

Class esh.in.explorer.api.security Extends %RegisteredObject
{

Parameter webapp = "/in-explorer/api";

ClassMethod SetupSecurity() As %Status
{
    Quit $$$OK
}

ClassMethod IntroduceSQLARole() As %Status
{
    &SQL(CREATE ROLE inexplorer)
    If (SQLCODE '= 0) && (SQLCODE '= -100) && (SQLCODE '= -118) {
        Quit $$$ERROR($$$GeneralError, "Error creating role: "_SQLCODE)
    }

    &SQL(GRANT SELECT,INSERT,UPDATE,DELETE ON esh_in_explorer.connections TO inexplorer)
    If SQLCODE '= 0 {
        If SQLCODE '= 100 {
            Quit $$$ERROR($$$GeneralError, "Error granting privileges on esh_in_explorer.connections: "_SQLCODE)
        }
    }

    &SQL(GRANT SELECT,INSERT,UPDATE,DELETE ON esh_in_explorer.connection_labels TO inexplorer)
    If SQLCODE '= 0 {
        If SQLCODE '= 100 {
            Quit $$$ERROR($$$GeneralError, "Error granting privileges on esh_in_explorer.connection_labels: "_SQLCODE)
        }
    }

    Quit $$$OK
}

ClassMethod IntroduceRoleDBUSER() As %Status
{
    &SQL(CREATE ROLE DB_USER_Read)
    If (SQLCODE '= 0) && (SQLCODE '= -100) && (SQLCODE '= -118) {
        Quit $$$ERROR($$$GeneralError, "Error creating role: "_SQLCODE)
    }

    New $NAMESPACE
    Set $NAMESPACE="%SYS"
    Set sc = ##class(Security.Roles).Get("DB_USER_Read", .properties)
    If $$$ISERR(sc) {
        Quit $$$ERROR($$$GeneralError, "Error reading role: "_sc)
    }
    If ("," _ $Get(properties("Resources")) _ ",") '[ ",%DB_USER:R," {
        Set $Piece(properties("Resources"), ",", *) = "%DB_USER:R"
    }
    Set sc = ##class(Security.Roles).Modify("DB_USER_Read", .properties)
    If $$$ISERR(sc) {
        Quit $$$ERROR($$$GeneralError, "Error modifying role: "_sc)
    }
    Quit sc
}

ClassMethod AddARoleToUser(user = "CSPSystem", appARole = "DB_USER_Read") As %Status
{
    New $NAMESPACE
    Set $NAMESPACE="%SYS"

    Set status = ##class(Security.Users).Get(user, .userProps)
    If $$$ISERR(status) {
        Quit status
    }
    If ("," _ $Get(userProps("Roles")) _ ",") '[ ("," _ appARole _ ",") {
        Set $Piece(userProps("Roles"), ",", *) = appARole
    }
    Set status = ##class(Security.Users).Modify(user, .userProps)
    Quit status
}

ClassMethod AddARole(appname = "", appARole = "inexplorer") As %Status
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

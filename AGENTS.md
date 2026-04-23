Don't use $Get() function for common (non multidimentional) properties of objectscirpt classes.

if you think to use $ListAppend function - use $ListBuild instead.

Role is a sacred word in IRIS SQL - so use ARole instead of Role everywhere

for cases like quit:pair = "" use quit:(pair = "")

creating swagger spec class in IRIS:
derive it from %REST.Spec
create swagger 2.0 version spec
Make sure you added OperationId into the every endpoint

don't forget to add basepath that correlates the web app you are building in IRIS


add parameters:
Parameter HandleCorsRequest = 1;

Parameter CONTENTTYPE = "application/json";

Name XData as OpenAPI with application/json MimeType:
XData OpenAPI [ MimeType = application/json ]

always add _spec endpoint:
"/_spec": {
      "get": {
        "summary": "Get OpenAPI spec",
        "operationId": "GetSpec",
        "responses": {
          "200": {
            "description": "Swagger spec JSON",
            "schema": { "type": "object" }
          }
        }
      }
    }

that always has the same implementation in the impl class:

/// /_spec
/// Get OpenAPI spec
ClassMethod GetSpec() As %DynamicObject
{
    set specname=$p(..%ClassName(1),".impl")
    Set spec = {}.%FromJSON(##class(%Dictionary.CompiledXData).%OpenId(specname_".spec||OpenAPI").Data)
	Set url = $Select(%request.Secure:"https",1:"http") _ "://"_$Get(%request.CgiEnvs("SERVER_NAME")) _ ":" _ $Get(%request.CgiEnvs("SERVER_PORT")) _ %request.Application
	Set spec.servers = [{"url" : (url)}]
	Quit spec
}


while adding REST API application element in module.xml use the following example:
<CSPApplication
        Url="/crud2"
        DispatchClass="dc.Sample.rest2.disp"
        MatchRoles=":{$dbrole}"
        PasswordAuthEnabled="0"
        UnauthenticatedEnabled="1"
        Recurse="1"
        UseCookies="2"
        CookiePath="/crud2/"
        CorsAllowlist="*"
        CorsCredentialsAllowed="1"
        CorsHeadersList="Content-Type,Authorization,Accept-Language,X-Requested-With,session"
       />
Url - is the web api name, and also an base path.
don't forget 3 cors related parameters listed in the end.

and also add the helper class security.cls with the same package and use the following example:

Class esh.lcrm.api.security Extends %RegisteredObject
{

Parameter webapp = "/lcrm/api";

ClassMethod SetupSecurity() As %Status
{
    Set tSC = $$$OK
    d ..IntroduceSQLRole()
    d ..AddRole()
    d ..AddCORS()
    d ..IntroduceRoleDBUSER()
    d ..AddRoleToUser()
    Quit tSC
}

ClassMethod IntroduceSQLRole() As %Status
{
    &SQL(CREATE ROLE lcrm)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error creating role: "_SQLCODE)
    }
    &SQL(GRANT SELECT,INSERT,UPDATE,DELETE on esh_lcrm.company to lcrm)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting privileges: "_SQLCODE)
    }
    &SQL(GRANT SELECT,INSERT,UPDATE,DELETE on esh_lcrm.companycabinet to lcrm)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting privileges: "_SQLCODE)
    }

    &SQL(GRANT SELECT,INSERT,UPDATE,DELETE on gc.cabinets to lcrm)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting privileges: "_SQLCODE)
    }
    &SQL(GRANT SELECT,INSERT,UPDATE,DELETE on gc.orders to lcrm)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting privileges: "_SQLCODE)
    }
    
    &SQL(GRANT SELECT,INSERT,UPDATE,DELETE on gc.users to lcrm)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error granting privileges: "_SQLCODE)
    
    }
    

    Quit $$$OK
}

ClassMethod IntroduceRoleDBUSER() As %Status
{
    &SQL(CREATE ROLE DB_USER_Read)
    If SQLCODE '= 0 {
        Quit $$$ERROR($$$GeneralError, "Error creating role: "_SQLCODE)
    }

    // Change to the %SYS namespace.
    new $NAMESPACE
    set $NAMESPACE="%SYS"
    set properties("Resources")="%DB_USER:R"
 
    Set sc = ##class(Security.Roles).Modify("DB_USER_Read",.properties)
    If $$$ISERR(sc) {
        Quit $$$ERROR($$$GeneralError, "Error modifying role: "_sc)
    }
    return sc
}

ClassMethod AddRoleToUser(user = "CSPSystem", role = "DB_USER_Read") As %Status
{
    // Change to the %SYS namespace.
    new $NAMESPACE
    set $NAMESPACE="%SYS"

    set status=##class(Security.Users).Get(user, .MyUserProps)
    set $p(MyUserProps("Roles"),",",*)=role
    set status=##class(Security.Users).Modify(user,.MyUserProps)

    // Announce success.
    if $$$ISOK(status) {
        write !, "Roles for the user "_user_" were successfully modified."
    }
    Quit status
}

ClassMethod AddRole(appname, approle = "lcrm") As %Status
{
    // Change to the %SYS namespace.
    new $NAMESPACE
    set $NAMESPACE="%SYS"

    set appname = $g(appname, ..#webapp)

    set status=##class(Security.Applications).Get(appname, .MyAppProps)
    set MyAppProps("MatchRoles")=MyAppProps("MatchRoles")_":"_approle

    set status=##class(Security.Applications).Modify(appname,.MyAppProps)

    // Announce success.
    if $$$ISOK(status) {
        write !, "Roles were successfully modified."
    }
    Quit status
}

ClassMethod AddCORS(appname) As %Status
{
    // Change to the %SYS namespace.
    new $NAMESPACE
    set $NAMESPACE="%SYS"
    set appname = $g(appname, ..#webapp)

    set status=##class(Security.Applications).Get(appname, .MyAppProps)
    set MyAppProps("CorsAllowlist")="*"
    set MyAppProps("CorsCredentialsAllowed")=1
    set MyAppProps("CorsHeadersList")="Content-Type,Authorization,X-Requested-With,Accept,Origin,Access-Control-Request-Method,Access-Control-Request-Headers"
    set status=##class(Security.Applications).Modify(appname,.MyAppProps)

    // Announce success.
    if $$$ISOK(status) {
        write !, "CORS methods were successfully added to."_appname
    }
    Quit status
}

}



Here is how you can build query implementations for openapi requests. E.g. here is the impl method to return sales:

ClassMethod ListCompanySales(companyId As %String, dateFrom As %String, dateTo As %String, limit As %Integer = 100, offset As %Integer = 0) As %DynamicObject
{
    set user=..GetAuthorizedUser() if user="" {return ""}
    if companyId = "" {
        d ..%SetStatusCode(400)
        d ..%SetHeader("X-Error", "companyId required")
        return {}
    }

    set rset = ##class(esh.lcrm.companycabinet).OrdersByCompanyFunc(companyId, dateFrom, dateTo, limit, offset)
    if rset.%SQLCODE<0 {
        d ..%SetStatusCode(500)
        d ..%SetHeader("X-Error", rset.%Message)
        return "" 
    }

    set dynArray = [].%New()
    While rset.%Next() {
        //s ^AAA="ID: "_rset.ID1
        do ##class(gc.orders).%OpenId(rset.ID1).%JSONExportToString(.json)
        set dynObj = {}.%FromJSON(json)
        do dynArray.%Push(dynObj)
    }

    set result = {}.%New()
    do result.%Set("items", dynArray)
    do result.%Set("count", dynArray.%Size())
    do result.%Set("limit", +limit)
    do result.%Set("offset", +offset)
    return result
}

Inside it calls OrdersByCompany with Func addition SQL class query, here is how it looks like:

Query OrdersByCompany(companyId As %String, dateFrom As %String = "", dateTo As %String = "", limit As %Integer = 100, offset As %Integer = 0) As %SQLQuery [ SqlProc ]
{
    SELECT  o.ID1 as ID1 
    FROM    gc.orders o 
    JOIN    esh_lcrm.companycabinet cc
            ON cc.CabinetId = o.take_cabinet_id
           AND cc.Company = :companyId
           AND (cc.StartDate IS NULL OR o.created_at >= cc.StartDate)
           AND (cc.EndDate IS NULL OR o.created_at <= cc.EndDate)
    WHERE   (:dateFrom = '' OR o.created_at >= dateFrom)
      AND   (:dateTo = '' OR o.created_at < :dateTo)
    ORDER BY o.created_at DESC
    LIMIT :limit OFFSET :offset
}


When you set to an object property - a property that refers another instance make sure the value you set is an instance of the object it refers.
E.g.
Set transaction.Product = sku
should be 
Set transaction.Product = ##class(HoleFoods.Product).%OpenId(sku)
as soon as Product property is defined as an object property reffering to HoleFoods.Product:
Property Product As HoleFoods.Product;
or refer the variable that contains the OREF for object obtained either with %OpenId() or %New() methods.

When handling errors for REST implementation methods in addition to providing error code, e.g. 500 also set the status code or SQLCode where it makes more sense, e.g.:

If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        d ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }

if the type is %Date use 0 for start date and $H for End date instead of "" default values
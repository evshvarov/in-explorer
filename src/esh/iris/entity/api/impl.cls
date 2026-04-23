Class esh.iris.entity.api.impl Extends %REST.Impl [ ProcedureBlock ]
{

Parameter ExposeServerExceptions = 1;

/// /_spec
/// Get OpenAPI spec
ClassMethod GetSpec() As %DynamicObject
{
    set specname=$p(..%ClassName(1),".impl")
    Set spec = {}.%FromJSON(##class(%Dictionary.CompiledXData).%OpenId(specname_".spec||OpenAPI").Data)
    Set url = $Select(%request.Secure:"https",1:"http") _ "://" _ $Get(%request.CgiEnvs("SERVER_NAME")) _ ":" _ $Get(%request.CgiEnvs("SERVER_PORT")) _ %request.Application
    Set spec.servers = [{"url" : (url)}]
    Quit spec
}

ClassMethod ListPersistentClasses(limit As %Integer = 100, offset As %Integer = 0, package As %String = "", includeSystem As %String = "", includeMapped As %String = "") As %DynamicObject
{
    Set limit = ..NormalizeLimit(limit)
    Set offset = ..NormalizeOffset(offset)
    Set includeSystem = ..NormalizeBoolean(includeSystem, 1)
    Set includeMapped = ..NormalizeBoolean(includeMapped, 1)
    Set result = ..NewPagedResult(limit, offset)
    Set stmt = ##class(%SQL.Statement).%New()
    Set sql = "SELECT Name, Description, SqlSchemaName, SqlTableName, System, CompileNamespace FROM %Dictionary.CompiledClass WHERE ClassType = ?"
    If $g(package) '= "" {
        Set sql = sql _ " AND Name %STARTSWITH ?"
    }
    Set sql = sql _ " ORDER BY Name"
    Set sc = stmt.%Prepare(sql)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }

    If $g(package) '= "" {
        Set rset = stmt.%Execute("persistent", package)
    } Else {
        Set rset = stmt.%Execute("persistent")
    }
    If rset.%SQLCODE < 0 {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "SQL error: "_rset.%Message)
        Quit result
    }

    Set skipped = 0
    Set collected = 0
    While rset.%Next() {
        Continue:'..ShouldIncludeClass(rset.%Get("System"), rset.%Get("CompileNamespace"), includeSystem, includeMapped)
        If skipped < offset {
            Set skipped = skipped + 1
            Continue
        }
        Quit:collected'<limit
        Set item = {}
        Set item.name = rset.%Get("Name")
        Set item.description = rset.%Get("Description")
        Set item.sqlSchemaName = rset.%Get("SqlSchemaName")
        Set item.sqlTableName = rset.%Get("SqlTableName")
        Do result.items.%Push(item)
        Set collected = collected + 1
    }

    Do result.%Set("count", result.items.%Size())
    Quit result
}

ClassMethod GetPersistentClassData(className As %String, limit As %Integer = 100, offset As %Integer = 0) As %DynamicObject
{
    Set limit = ..NormalizeLimit(limit)
    Set offset = ..NormalizeOffset(offset)
    Set result = ..NewPagedResult(limit, offset)
    Do result.%Set("className", className)
    If ('..IsValidClassName(className)) {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "Invalid className")
        Quit result
    }

    Set classInfo = ..GetPersistentClassInfo(className)
    If '$IsObject(classInfo) {
        Do ..%SetStatusCode(404)
        Do ..%SetHeader("X-Error", "Persistent class not found: "_className)
        Quit result
    }

    Set propInfos = ..GetClassPropertyInfos(className)
    If '$IsObject(propInfos) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Unable to resolve properties for class: "_className)
        Quit result
    }

    Set extent = ##class(%ResultSet).%New(className_":Extent")
    Set sc = extent.Execute()
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }

    Set skipped = 0
    Set collected = 0
    While extent.Next() {
        If skipped < offset {
            Set skipped = skipped + 1
            Continue
        }
        Quit:collected'<limit
        Set objectId = extent.Data("ID")
        Set obj = $classmethod(className, "%OpenId", objectId)
        Continue:'$IsObject(obj)
        Set item = {}
        Do item.%Set("%Id", objectId)
        Do ..PopulateObjectData(.item, obj, propInfos)
        Do result.items.%Push(item)
        Set collected = collected + 1
    }

    Do result.%Set("count", result.items.%Size())
    Quit result
}

ClassMethod GetPersistentClassStats(className As %String) As %DynamicObject
{
    Set result = {}
    Do result.%Set("namespace", $Namespace)
    Do result.%Set("className", className)
    Do result.%Set("totalRows", 0)
    Do result.%Set("columns", [])
    If ('..IsValidClassName(className)) {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "Invalid className")
        Quit result
    }

    Set classInfo = ..GetPersistentClassInfo(className)
    If '$IsObject(classInfo) {
        Do ..%SetStatusCode(404)
        Do ..%SetHeader("X-Error", "Persistent class not found: "_className)
        Quit result
    }

    Set result = ##class(esh.iris.entity.stats).CalculatePopulationStats(className, .sc)
    If $$$ISERR(sc) {
        Do ..%SetStatusCode(500)
        Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        Quit result
    }
    Quit result
}

ClassMethod GetPersistentClassEmptyRecords(className As %String, columnName As %String, limit As %Integer = 100, offset As %Integer = 0) As %DynamicObject
{
    Set limit = ..NormalizeLimit(limit)
    Set offset = ..NormalizeOffset(offset)
    Set result = ..NewPagedResult(limit, offset)
    Do result.%Set("className", className)
    Do result.%Set("columnName", columnName)
    If ('..IsValidClassName(className)) {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "Invalid className")
        Quit result
    }
    If columnName = "" {
        Do ..%SetStatusCode(400)
        Do ..%SetHeader("X-Error", "columnName required")
        Quit result
    }

    Set classInfo = ..GetPersistentClassInfo(className)
    If '$IsObject(classInfo) {
        Do ..%SetStatusCode(404)
        Do ..%SetHeader("X-Error", "Persistent class not found: "_className)
        Quit result
    }

    Set result = ##class(esh.iris.entity.stats).GetRecordsWithEmptyValue(className, columnName, limit, offset, .sc)
    If $$$ISERR(sc) {
        If $System.Status.GetErrorText(sc)["Property not found: " {
            Do ..%SetStatusCode(400)
            Do ..%SetHeader("X-Error", $System.Status.GetErrorText(sc))
        } Else {
            Do ..%SetStatusCode(500)
            Do ..%SetHeader("X-Error", "Status error: "_$System.Status.GetErrorText(sc))
        }
        Quit result
    }
    Quit result
}

ClassMethod NewPagedResult(limit As %Integer, offset As %Integer) As %DynamicObject [ Private ]
{
    Set result = {}
    Do result.%Set("namespace", $Namespace)
    Do result.%Set("items", [])
    Do result.%Set("count", 0)
    Do result.%Set("limit", ..NormalizeLimit(limit))
    Do result.%Set("offset", ..NormalizeOffset(offset))
    Quit result
}

ClassMethod NormalizeLimit(limit As %Integer) As %Integer [ Private ]
{
    Quit $Select(limit>0:limit, 1:100)
}

ClassMethod NormalizeOffset(offset As %Integer) As %Integer [ Private ]
{
    Quit $Select(offset'<0:offset, 1:0)
}

ClassMethod NormalizeBoolean(value, defaultValue As %Boolean = 1) As %Boolean [ Private ]
{
    If value = "" {
        Quit defaultValue
    }
    If +value = 0 {
        Quit 0
    }

    Set normalized = $ZConvert(value, "L")
    If (normalized = "false") || (normalized = "no") {
        Quit 0
    }
    Quit 1
}

ClassMethod ShouldIncludeClass(system, compileNamespace As %String, includeSystem As %Boolean, includeMapped As %Boolean) As %Boolean [ Private ]
{
    If ('includeSystem),(+system '= 0) {
        Quit 0
    }
    If 'includeMapped {
        If compileNamespace = "" {
            Quit 0
        }
        If compileNamespace '[ ("^" _ $Namespace) {
            Quit 0
        }
    }
    Quit 1
}

ClassMethod IsValidClassName(className As %String) As %Boolean [ Private ]
{
    Set length = $Length(className)
    If length = 0 {
        Quit 0
    }

    Set valid = 1
    For index = 1:1:length {
        Set ch = $Extract(className, index)
        Continue:((ch?1A) || (ch?1N) || (ch = ".") || (ch = "%"))
        Set valid = 0
        Quit
    }

    Quit valid
}

ClassMethod GetPersistentClassInfo(className As %String) As %DynamicObject [ Private ]
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("SELECT Name, SqlSchemaName, SqlTableName FROM %Dictionary.CompiledClass WHERE Name = ? AND ClassType = ?")
    If $$$ISERR(sc) {
        Quit ""
    }

    Set rset = stmt.%Execute(className, "persistent")
    If rset.%SQLCODE < 0 {
        Quit ""
    }
    If 'rset.%Next() {
        Quit ""
    }

    Set item = {}
    Set item.Name = rset.%Get("Name")
    Set item.SqlSchemaName = rset.%Get("SqlSchemaName")
    Set item.SqlTableName = rset.%Get("SqlTableName")
    Quit item
}

ClassMethod GetClassPropertyInfos(className As %String) As %DynamicArray [ Private ]
{
    Set stmt = ##class(%SQL.Statement).%New()
    Set sql = "SELECT Name, Type FROM %Dictionary.CompiledProperty WHERE parent = ? AND Private = 0 AND Transient = 0 AND Calculated = 0 AND MultiDimensional = 0 ORDER BY Name"
    Set sc = stmt.%Prepare(sql)
    If $$$ISERR(sc) {
        Quit ""
    }

    Set rset = stmt.%Execute(className)
    If rset.%SQLCODE < 0 {
        Quit ""
    }

    Set propInfos = []
    While rset.%Next() {
        Set propInfo = {}
        Set propInfo.name = rset.%Get("Name")
        Set propInfo.type = rset.%Get("Type")
        Do propInfos.%Push(propInfo)
    }
    Quit propInfos
}

ClassMethod PopulateObjectData(ByRef item As %DynamicObject, obj As %RegisteredObject, propInfos As %DynamicArray) [ Private ]
{
    Set index = -1
    While (index + 1) < propInfos.%Size() {
        Set index = index + 1
        Set propInfo = propInfos.%Get(index)
        Set propName = propInfo.name
        Try {
            Set value = $PROPERTY(obj, propName)
            Do item.%Set(propName, ..NormalizeValue(value, propInfo.type))
        } Catch ex {
            Continue
        }
    }
}

ClassMethod NormalizeValue(value, type As %String = "") [ Private ]
{
    If $IsObject(value) {
        Set ref = {}
        Do ref.%Set("className", value.%ClassName(1))
        Do ref.%Set("id", value.%Id())
        Quit ref
    }

    If $Extract(type, 1) = "%" {
        Quit value
    }

    If value = "" {
        Quit value
    }

    Set ref = {}
    Do ref.%Set("className", type)
    Do ref.%Set("id", value)
    Quit ref
}

}

Class esh.in.explorer.connectiontag Extends %Persistent [ SqlTableName = connection_labels ]
{

Property ParentConnection As esh.in.explorer.connection [ Required ];

Property Kind As %String(MAXLEN = 20);

Property Value As %String(MAXLEN = 200);

Index ConnectionKindIdx On (ParentConnection, Kind);

Index KindValueIdx On (Kind, Value);

Query ListByConnectionAndKind(connectionId As %Integer, kind As %String) As %SQLQuery [ SqlProc ]
{
    SELECT Value
    FROM esh_in_explorer.connection_labels
    WHERE ParentConnection = :connectionId
      AND Kind = :kind
    ORDER BY Value
}

Query FacetByKind(search As %String = "", kind As %String) As %SQLQuery [ SqlProc ]
{
    SELECT t.Value AS Value, COUNT(*) AS ItemCount
    FROM esh_in_explorer.connection_labels AS t
    JOIN esh_in_explorer.connections AS c
      ON t.ParentConnection = c.%ID
    WHERE t.Kind = :kind
      AND (:search = ''
           OR UPPER(c.linkedin_id) LIKE UPPER(:search)
           OR UPPER(c.first_name) LIKE UPPER(:search)
           OR UPPER(c.last_name) LIKE UPPER(:search)
           OR UPPER(c.Company) LIKE UPPER(:search)
           OR UPPER(c.Position) LIKE UPPER(:search)
           OR UPPER(c.Email) LIKE UPPER(:search)
           OR UPPER(c.Notes) LIKE UPPER(:search)
           OR UPPER((COALESCE(c.first_name,'') || ' ' || COALESCE(c.last_name,''))) LIKE UPPER(:search))
    GROUP BY t.Value
    ORDER BY COUNT(*) DESC, t.Value ASC
}

ClassMethod DeleteByConnectionAndKind(connection As esh.in.explorer.connection, kind As %String) As %Status
{
    If '$IsObject(connection) {
        Quit $$$OK
    }
    If connection.%Id() = "" {
        Quit $$$OK
    }

    Set stmt = ##class(%SQL.Statement).%New()
    Set sc = stmt.%Prepare("DELETE FROM esh_in_explorer.connection_labels WHERE ParentConnection = ? AND Kind = ?")
    If $$$ISERR(sc) {
        Quit sc
    }
    Set rset = stmt.%Execute(connection.%Id(), kind)
    If rset.%SQLCODE < 0 {
        Quit $$$ERROR($$$GeneralError, "SQL error: "_rset.%Message)
    }
    Quit $$$OK
}

}

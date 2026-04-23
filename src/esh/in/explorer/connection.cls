Class esh.in.explorer.connection Extends %Persistent [ SqlTableName = connections ]
{

Property LinkedInId As %String(MAXLEN = 200) [ Required, SqlFieldName = linkedin_id ];

Property FirstName As %String(MAXLEN = 100) [ SqlFieldName = first_name ];

Property LastName As %String(MAXLEN = 100) [ SqlFieldName = last_name ];

Property Url As %String(MAXLEN = 500);

Property Email As %String(MAXLEN = 320);

Property Company As %String(MAXLEN = 200);

Property Position As %String(MAXLEN = 200);

Property ConnectedOn As %Date [ SqlFieldName = connected_on ];

Property City As %String(MAXLEN = 150);

Property Country As %String(MAXLEN = 150);

Property Industry As %String(MAXLEN = 150);

Property Notes As %String(MAXLEN = "");

Index LinkedInIdIdx On LinkedInId [ Unique ];

Query ListConnections(search As %String = "", city As %String = "", industry As %String = "", company As %String = "", ARoleFilter As %String = "", tag As %String = "", sort As %String = "recent", limit As %Integer = 50, offset As %Integer = 0) As %SQLQuery [ SqlProc ]
{
    SELECT c.%ID AS ID
    FROM esh_in_explorer.connections AS c
    WHERE (:search = ''
           OR UPPER(c.linkedin_id) LIKE UPPER(:search)
           OR UPPER(c.first_name) LIKE UPPER(:search)
           OR UPPER(c.last_name) LIKE UPPER(:search)
           OR UPPER(c.Company) LIKE UPPER(:search)
           OR UPPER(c.Position) LIKE UPPER(:search)
           OR UPPER(c.Email) LIKE UPPER(:search)
           OR UPPER(c.Notes) LIKE UPPER(:search)
           OR UPPER((COALESCE(c.first_name,'') || ' ' || COALESCE(c.last_name,''))) LIKE UPPER(:search))
      AND (:city = '' OR UPPER(c.City) = UPPER(:city))
      AND (:industry = '' OR UPPER(c.Industry) = UPPER(:industry))
      AND (:company = '' OR UPPER(c.Company) = UPPER(:company))
      AND (:ARoleFilter = '' OR EXISTS (
            SELECT 1
            FROM esh_in_explorer.connection_labels AS t1
            WHERE t1.ParentConnection = c.%ID
              AND t1.Kind = 'arole'
              AND UPPER(t1.Value) = UPPER(:ARoleFilter)))
      AND (:tag = '' OR EXISTS (
            SELECT 1
            FROM esh_in_explorer.connection_labels AS t2
            WHERE t2.ParentConnection = c.%ID
              AND t2.Kind = 'tag'
              AND UPPER(t2.Value) = UPPER(:tag)))
    ORDER BY c.connected_on DESC, UPPER(c.last_name) ASC, UPPER(c.first_name) ASC, c.linkedin_id ASC
    LIMIT :limit OFFSET :offset
}

Query CountConnections(search As %String = "", city As %String = "", industry As %String = "", company As %String = "", ARoleFilter As %String = "", tag As %String = "") As %SQLQuery [ SqlProc ]
{
    SELECT COUNT(*) AS Total
    FROM esh_in_explorer.connections AS c
    WHERE (:search = ''
           OR UPPER(c.linkedin_id) LIKE UPPER(:search)
           OR UPPER(c.first_name) LIKE UPPER(:search)
           OR UPPER(c.last_name) LIKE UPPER(:search)
           OR UPPER(c.Company) LIKE UPPER(:search)
           OR UPPER(c.Position) LIKE UPPER(:search)
           OR UPPER(c.Email) LIKE UPPER(:search)
           OR UPPER(c.Notes) LIKE UPPER(:search)
           OR UPPER((COALESCE(c.first_name,'') || ' ' || COALESCE(c.last_name,''))) LIKE UPPER(:search))
      AND (:city = '' OR UPPER(c.City) = UPPER(:city))
      AND (:industry = '' OR UPPER(c.Industry) = UPPER(:industry))
      AND (:company = '' OR UPPER(c.Company) = UPPER(:company))
      AND (:ARoleFilter = '' OR EXISTS (
            SELECT 1
            FROM esh_in_explorer.connection_labels AS t1
            WHERE t1.ParentConnection = c.%ID
              AND t1.Kind = 'arole'
              AND UPPER(t1.Value) = UPPER(:ARoleFilter)))
      AND (:tag = '' OR EXISTS (
            SELECT 1
            FROM esh_in_explorer.connection_labels AS t2
            WHERE t2.ParentConnection = c.%ID
              AND t2.Kind = 'tag'
              AND UPPER(t2.Value) = UPPER(:tag)))
}

Query FindByLinkedInId(linkedInId As %String) As %SQLQuery [ SqlProc ]
{
    SELECT %ID AS ID
    FROM esh_in_explorer.connections
    WHERE linkedin_id = :linkedInId
}

Query FacetCities(search As %String = "") As %SQLQuery [ SqlProc ]
{
    SELECT c.City AS Value, COUNT(*) AS ItemCount
    FROM esh_in_explorer.connections AS c
    WHERE c.City IS NOT NULL
      AND c.City <> ''
      AND (:search = ''
           OR UPPER(c.linkedin_id) LIKE UPPER(:search)
           OR UPPER(c.first_name) LIKE UPPER(:search)
           OR UPPER(c.last_name) LIKE UPPER(:search)
           OR UPPER(c.Company) LIKE UPPER(:search)
           OR UPPER(c.Position) LIKE UPPER(:search)
           OR UPPER(c.Email) LIKE UPPER(:search)
           OR UPPER(c.Notes) LIKE UPPER(:search)
           OR UPPER((COALESCE(c.first_name,'') || ' ' || COALESCE(c.last_name,''))) LIKE UPPER(:search))
    GROUP BY c.City
    ORDER BY COUNT(*) DESC, c.City ASC
}

Query FacetIndustries(search As %String = "") As %SQLQuery [ SqlProc ]
{
    SELECT c.Industry AS Value, COUNT(*) AS ItemCount
    FROM esh_in_explorer.connections AS c
    WHERE c.Industry IS NOT NULL
      AND c.Industry <> ''
      AND (:search = ''
           OR UPPER(c.linkedin_id) LIKE UPPER(:search)
           OR UPPER(c.first_name) LIKE UPPER(:search)
           OR UPPER(c.last_name) LIKE UPPER(:search)
           OR UPPER(c.Company) LIKE UPPER(:search)
           OR UPPER(c.Position) LIKE UPPER(:search)
           OR UPPER(c.Email) LIKE UPPER(:search)
           OR UPPER(c.Notes) LIKE UPPER(:search)
           OR UPPER((COALESCE(c.first_name,'') || ' ' || COALESCE(c.last_name,''))) LIKE UPPER(:search))
    GROUP BY c.Industry
    ORDER BY COUNT(*) DESC, c.Industry ASC
}

Query FacetCompanies(search As %String = "") As %SQLQuery [ SqlProc ]
{
    SELECT c.Company AS Value, COUNT(*) AS ItemCount
    FROM esh_in_explorer.connections AS c
    WHERE c.Company IS NOT NULL
      AND c.Company <> ''
      AND (:search = ''
           OR UPPER(c.linkedin_id) LIKE UPPER(:search)
           OR UPPER(c.first_name) LIKE UPPER(:search)
           OR UPPER(c.last_name) LIKE UPPER(:search)
           OR UPPER(c.Company) LIKE UPPER(:search)
           OR UPPER(c.Position) LIKE UPPER(:search)
           OR UPPER(c.Email) LIKE UPPER(:search)
           OR UPPER(c.Notes) LIKE UPPER(:search)
           OR UPPER((COALESCE(c.first_name,'') || ' ' || COALESCE(c.last_name,''))) LIKE UPPER(:search))
    GROUP BY c.Company
    ORDER BY COUNT(*) DESC, c.Company ASC
}

ClassMethod OpenByLinkedInId(linkedInId As %String) As esh.in.explorer.connection
{
    Quit:(linkedInId = "") ""
    Set rset = ..FindByLinkedInIdFunc(linkedInId)
    If rset.%SQLCODE < 0 {
        Quit ""
    }
    If 'rset.%Next() {
        Quit ""
    }
    Quit ..%OpenId(rset.%Get("ID"))
}

ClassMethod NormalizeSearch(search As %String = "") As %String
{
    Quit $Select(search = "":"", 1:"%" _ search _ "%")
}

}

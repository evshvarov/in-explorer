Class esh.in.explorer.connectionimport Extends %RegisteredObject
{

Parameter DefaultCSVPath = "/home/irisowner/dev/data/Connections.csv";

ClassMethod ImportFromFile(path As %String = "", ByRef summary) As %Status
{
    Set tSC = $$$OK
    Set filePath = path
    Set processed = 0
    Set imported = 0
    Set inserted = 0
    Set updated = 0
    Set skipped = 0
    Set failed = 0
    Set errors = []
    Kill headerMap

    If filePath = "" {
        Set filePath = ..#DefaultCSVPath
    }

    Set summary = ..NewSummary(filePath)
    Set stream = ##class(%Stream.FileCharacter).%New()
    Set tSC = stream.LinkToFile(filePath)
    If $$$ISERR(tSC) {
        Do summary.%Set("status", "error")
        Do errors.%Push(..ErrorItem(0, $System.Status.GetErrorText(tSC)))
        Do summary.%Set("errors", errors)
        Quit tSC
    }

    Do stream.Rewind()
    Set lineNumber = 0
    Set headerFound = 0
    Set fatalError = 0

    While 'stream.AtEnd {
        Set line = $Translate(stream.ReadLine(), $C(13), "")
        Set lineNumber = lineNumber + 1

        If 'headerFound {
            If ..Trim(line) = "" {
                Continue
            }
            If ..LooksLikeHeader(line) {
                Set tSC = ..BuildHeaderMap(line, .headerMap)
                If $$$ISERR(tSC) {
                    Do summary.%Set("status", "error")
                    Do errors.%Push(..ErrorItem(lineNumber, $System.Status.GetErrorText(tSC)))
                    Do summary.%Set("errors", errors)
                    Set fatalError = 1
                    Quit
                }
                Set headerFound = 1
            }
            Continue
        }

        If ..Trim(line) = "" {
            Continue
        }
        Set processed = processed + 1
        Set row = ..ParseCSVLine(line)
        Set rowSC = ..ImportRow(row, .headerMap, .action, .message)
        If $$$ISERR(rowSC) {
            Set failed = failed + 1
            If errors.%Size() < 20 {
                Do errors.%Push(..ErrorItem(lineNumber, $System.Status.GetErrorText(rowSC)))
            }
            Continue
        }
        If action = "inserted" {
            Set imported = imported + 1
            Set inserted = inserted + 1
            Continue
        }
        If action = "updated" {
            Set imported = imported + 1
            Set updated = updated + 1
            Continue
        }
        If action = "skipped" {
            Set skipped = skipped + 1
            If (message '= "") && (errors.%Size() < 20) {
                Do errors.%Push(..ErrorItem(lineNumber, message))
            }
        }
    }

    If fatalError {
        Quit tSC
    }

    If 'headerFound {
        Set tSC = $$$ERROR($$$GeneralError, "Connections CSV header was not found")
        Do summary.%Set("status", "error")
        Do errors.%Push(..ErrorItem(0, $System.Status.GetErrorText(tSC)))
        Do summary.%Set("errors", errors)
        Quit tSC
    }

    Do summary.%Set("processed", processed)
    Do summary.%Set("imported", imported)
    Do summary.%Set("inserted", inserted)
    Do summary.%Set("updated", updated)
    Do summary.%Set("skipped", skipped)
    Do summary.%Set("failed", failed)
    Do summary.%Set("errors", errors)
    Do summary.%Set("status", $Select(failed > 0:"partial", 1:"ok"))
    Quit tSC
}

ClassMethod NewSummary(path As %String) As %DynamicObject
{
    Set summary = {}
    Do summary.%Set("path", path)
    Do summary.%Set("status", "ok")
    Do summary.%Set("processed", 0)
    Do summary.%Set("imported", 0)
    Do summary.%Set("inserted", 0)
    Do summary.%Set("updated", 0)
    Do summary.%Set("skipped", 0)
    Do summary.%Set("failed", 0)
    Do summary.%Set("errors", [])
    Quit summary
}

ClassMethod ErrorItem(lineNumber As %Integer, message As %String) As %DynamicObject
{
    Set item = {}
    Do item.%Set("line", lineNumber)
    Do item.%Set("message", message)
    Quit item
}

ClassMethod LooksLikeHeader(line As %String) As %Boolean
{
    Set trimmed = ..Trim(line)
    Quit (trimmed [ "First Name") && (trimmed [ ",URL,") && (trimmed [ "Connected On")
}

ClassMethod BuildHeaderMap(line As %String, ByRef headerMap) As %Status
{
    Set columns = ..ParseCSVLine(line)
    Kill headerMap
    For index = 0:1:(columns.%Size() - 1) {
        Set headerMap(..Trim(columns.%Get(index))) = index
    }
    If '$Data(headerMap("First Name")) {
        Quit $$$ERROR($$$GeneralError, "Connections CSV is missing First Name column")
    }
    If '$Data(headerMap("Last Name")) {
        Quit $$$ERROR($$$GeneralError, "Connections CSV is missing Last Name column")
    }
    If '$Data(headerMap("URL")) {
        Quit $$$ERROR($$$GeneralError, "Connections CSV is missing URL column")
    }
    If '$Data(headerMap("Connected On")) {
        Quit $$$ERROR($$$GeneralError, "Connections CSV is missing Connected On column")
    }
    Quit $$$OK
}

ClassMethod ImportRow(columns As %DynamicArray, ByRef headerMap, ByRef action As %String, ByRef message As %String) As %Status
{
    Set tSC = $$$OK
    Set action = ""
    Set message = ""
    Set url = ..CsvValue(columns, .headerMap, "URL")
    Set linkedInId = ..LinkedInIdFromUrl(url)
    If linkedInId = "" {
        Set action = "skipped"
        Set message = "Missing LinkedIn URL slug"
        Quit tSC
    }

    Set connection = ##class(esh.in.explorer.connection).OpenByLinkedInId(linkedInId)
    If '$IsObject(connection) {
        Set connection = ##class(esh.in.explorer.connection).%New()
        Set connection.LinkedInId = linkedInId
        Set action = "inserted"
    } Else {
        Set action = "updated"
    }

    Set connection.FirstName = ..CsvValue(columns, .headerMap, "First Name")
    Set connection.LastName = ..CsvValue(columns, .headerMap, "Last Name")
    Set connection.Url = url
    Set connection.Email = ..CsvValue(columns, .headerMap, "Email Address")
    Set connection.Company = ..CsvValue(columns, .headerMap, "Company")
    Set connection.Position = ..CsvValue(columns, .headerMap, "Position")

    Set connectedOn = ..CsvValue(columns, .headerMap, "Connected On")
    If connectedOn = "" {
        Set connection.ConnectedOn = ""
    } Else {
        Set connection.ConnectedOn = ..NormalizeDate(connectedOn, .dateSC)
        If $$$ISERR(dateSC) {
            Quit dateSC
        }
    }

    If connection.Url = "" {
        Set connection.Url = "https://www.linkedin.com/in/" _ linkedInId
    }

    Set tSC = connection.%Save()
    If $$$ISERR(tSC) {
        Quit tSC
    }
    Quit tSC
}

ClassMethod CsvValue(columns As %DynamicArray, ByRef headerMap, name As %String) As %String
{
    If '$Data(headerMap(name)) {
        Quit ""
    }
    Set index = headerMap(name)
    If (index < 0) || (index >= columns.%Size()) {
        Quit ""
    }
    Quit ..Trim(columns.%Get(index))
}

ClassMethod ParseCSVLine(line As %String) As %DynamicArray
{
    Set result = []
    Set value = ""
    Set inQuotes = 0
    Set position = 1
    Set length = $Length(line)

    While position <= length {
        Set ch = $Extract(line, position)
        If inQuotes {
            If ch = """" {
                If (position < length) && ($Extract(line, position + 1) = """") {
                    Set value = value _ """"
                    Set position = position + 2
                    Continue
                }
                Set inQuotes = 0
                Set position = position + 1
                Continue
            }
            Set value = value _ ch
            Set position = position + 1
            Continue
        }
        If ch = "," {
            Do result.%Push(value)
            Set value = ""
            Set position = position + 1
            Continue
        }
        If ch = """" {
            Set inQuotes = 1
            Set position = position + 1
            Continue
        }
        Set value = value _ ch
        Set position = position + 1
    }

    Do result.%Push(value)
    Quit result
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

ClassMethod Trim(value As %String = "") As %String
{
    Quit $ZStrip(value, "<>W")
}

}

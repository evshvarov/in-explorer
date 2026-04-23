Class esh.iris.entity.tests.UnitTests Extends %UnitTest.TestCase
{

Method InitRequestResponse() [ Private ]
{
    Set %response = ##class(%CSP.Response).%New()
    Set %request = ##class(%CSP.Request).%New()
    Set %request.CgiEnvs("SERVER_NAME") = "localhost"
    Set %request.CgiEnvs("SERVER_PORT") = "52773"
}

Method CreateSampleData(ByRef parentId As %String, ByRef childId As %String) [ Private ]
{
    Set parent = ##class(esh.iris.entity.tests.SampleParent).%New()
    Set parent.Name = "Parent "_$J_"-"_$Random(10000)
    Set sc = parent.%Save()
    Do $$$AssertStatusOK(sc, "Saving sample parent failed")

    Set child = ##class(esh.iris.entity.tests.SampleChild).%New()
    Set child.Name = "Child "_$J_"-"_$Random(10000)
    Set child.Amount = 42
    Set child.Parent = parent
    Set sc = child.%Save()
    Do $$$AssertStatusOK(sc, "Saving sample child failed")

    Set parentId = parent.%Id()
    Set childId = child.%Id()
}

Method CleanupSampleData(parentId As %String, childId As %String) [ Private ]
{
    If childId '= "" {
        Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId)
    }
    If parentId '= "" {
        Do ##class(esh.iris.entity.tests.SampleParent).%DeleteId(parentId)
    }
}

Method FindClassByName(items As %DynamicArray, target As %String) As %DynamicObject [ Private ]
{
    Set found = ""
    For i = 0:1:items.%Size()-1 {
        Set item = items.%Get(i)
        If $IsObject(item) {
            If item.name = target {
                Set found = item
                Quit
            }
        }
    }
    Quit found
}

Method FindRowById(items As %DynamicArray, targetId As %String) As %DynamicObject [ Private ]
{
    Set found = ""
    For i = 0:1:items.%Size()-1 {
        Set item = items.%Get(i)
        If $IsObject(item) {
            If item.%Get("%Id") = targetId {
                Set found = item
                Quit
            }
        }
    }
    Quit found
}

Method FindColumnByName(columns As %DynamicArray, target As %String) As %DynamicObject [ Private ]
{
    Set found = ""
    For i = 0:1:columns.%Size()-1 {
        Set item = columns.%Get(i)
        If $IsObject(item) {
            If item.name = target {
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
    Set spec = ##class(esh.iris.entity.api.impl).GetSpec()
    Do $$$AssertTrue($IsObject(spec), "Spec response must be an object")
    Do $$$AssertEquals(spec.swagger, "2.0", "Unexpected swagger version")
    Do $$$AssertTrue(spec.paths.%IsDefined("/classes"), "Spec must expose /classes")
    Do $$$AssertTrue(spec.paths.%IsDefined("/classes/{className}/data"), "Spec must expose class data endpoint")
    Do $$$AssertTrue(spec.paths.%IsDefined("/classes/{className}/stats"), "Spec must expose class stats endpoint")
    Do $$$AssertTrue(spec.paths.%IsDefined("/classes/{className}/empty-records"), "Spec must expose empty records endpoint")
    Do $$$AssertTrue(spec.paths.%Get("/classes").get.parameters.%Size() > 3, "Spec must expose class filters")
}

Method TestListPersistentClasses()
{
    Do ..InitRequestResponse()
    Set result = ##class(esh.iris.entity.api.impl).ListPersistentClasses(200, 0, "esh.iris.entity.tests.")
    Do $$$AssertTrue($IsObject(result), "List response must be an object")
    Do $$$AssertEquals(result.namespace, $Namespace, "Namespace mismatch")
    Do $$$AssertEquals(result.limit, 200, "Limit mismatch")
    Do $$$AssertEquals(result.offset, 0, "Offset mismatch")
    Do $$$AssertTrue($IsObject(result.items), "Items must be a dynamic array")

    Set classInfo = ..FindClassByName(result.items, "esh.iris.entity.tests.SampleChild")
    Do $$$AssertTrue($IsObject(classInfo), "SampleChild should be listed as persistent")
    Do $$$AssertEquals(classInfo.sqlTableName, "SampleChild", "Unexpected SQL table name")
}

Method TestListPersistentClassesExcludeSystemAndMapped()
{
    Do ..InitRequestResponse()
    Set result = ##class(esh.iris.entity.api.impl).ListPersistentClasses(500, 0, "", 0, 0)
    Do $$$AssertTrue($IsObject(result), "Filtered list response must be an object")
    Do $$$AssertTrue($IsObject(result.items), "Filtered items must be a dynamic array")

    Set systemClassInfo = ..FindClassByName(result.items, "%CSP.Session")
    Do $$$AssertTrue('$IsObject(systemClassInfo), "System class should be filtered out")

    Set classInfo = ..FindClassByName(result.items, "esh.iris.entity.tests.SampleChild")
    Do $$$AssertTrue($IsObject(classInfo), "Local non-system class should remain in filtered list")
}

Method TestGetPersistentClassData()
{
    Do ..InitRequestResponse()
    Set parentId = "", childId = ""
    Try {
        Do ..CreateSampleData(.parentId, .childId)
        Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassData("esh.iris.entity.tests.SampleChild", 50, 0)
        Do $$$AssertTrue($IsObject(result), "Data response must be an object")
        Do $$$AssertEquals(result.className, "esh.iris.entity.tests.SampleChild", "Class name mismatch")
        Do $$$AssertEquals(result.limit, 50, "Limit mismatch")
        Do $$$AssertTrue($IsObject(result.items), "Items must be a dynamic array")

        Set row = ..FindRowById(result.items, childId)
        Do $$$AssertTrue($IsObject(row), "Inserted SampleChild row not found")
        Do $$$AssertEquals(row.Name, ##class(esh.iris.entity.tests.SampleChild).%OpenId(childId).Name, "Name mismatch")
        Do $$$AssertEquals(row.Amount, 42, "Amount mismatch")
        Do $$$AssertTrue($IsObject(row.Parent), "Parent reference should be serialized as object")
        Do $$$AssertEquals(row.Parent.className, "esh.iris.entity.tests.SampleParent", "Parent class mismatch")
        Do $$$AssertEquals(row.Parent.id, parentId, "Parent id mismatch")
    } Catch ex {
        Do ..CleanupSampleData(parentId, childId)
        Throw ex
    }
    Do ..CleanupSampleData(parentId, childId)
}

Method TestGetPersistentClassDataInvalidClass()
{
    Do ..InitRequestResponse()
    Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassData("bad class name", 10, 0)
    Do $$$AssertTrue($IsObject(result), "Invalid class response must be an object")
    Do $$$AssertEquals(%response.Status, 400, "Invalid class should set 400")
}

Method TestGetPersistentClassDataMissingClass()
{
    Do ..InitRequestResponse()
    Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassData("esh.iris.entity.tests.DoesNotExist", 10, 0)
    Do $$$AssertTrue($IsObject(result), "Missing class response must be an object")
    Do $$$AssertEquals(%response.Status, 404, "Missing class should set 404")
}

Method TestGetPersistentClassStats()
{
    Do ..InitRequestResponse()
    Set parentId = ""
    Set childId1 = ""
    Set childId2 = ""
    Try {
        Set parent = ##class(esh.iris.entity.tests.SampleParent).%New()
        Set parent.Name = "Stats Parent "_$J_"-"_$Random(10000)
        Set sc = parent.%Save()
        Do $$$AssertStatusOK(sc, "Saving stats parent failed")

        Set child1 = ##class(esh.iris.entity.tests.SampleChild).%New()
        Set child1.Name = "Filled Child "_$J_"-"_$Random(10000)
        Set child1.Amount = 42
        Set child1.Parent = parent
        Set sc = child1.%Save()
        Do $$$AssertStatusOK(sc, "Saving first stats child failed")

        Set child2 = ##class(esh.iris.entity.tests.SampleChild).%New()
        Set child2.Name = ""
        Set sc = child2.%Save()
        Do $$$AssertStatusOK(sc, "Saving second stats child failed")

        Set parentId = parent.%Id()
        Set childId1 = child1.%Id()
        Set childId2 = child2.%Id()

        Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassStats("esh.iris.entity.tests.SampleChild")
        Do $$$AssertTrue($IsObject(result), "Stats response must be an object")
        Do $$$AssertEquals(result.className, "esh.iris.entity.tests.SampleChild", "Stats class name mismatch")
        Do $$$AssertTrue(result.totalRows >= 2, "Stats totalRows should include inserted rows")
        Do $$$AssertTrue($IsObject(result.columns), "Stats columns must be a dynamic array")

        Set amountStats = ..FindColumnByName(result.columns, "Amount")
        Do $$$AssertTrue($IsObject(amountStats), "Amount stats should exist")
        Do $$$AssertTrue(amountStats.populatedCount >= 1, "Amount populated count should be at least 1")
        Do $$$AssertTrue(amountStats.emptyCount >= 1, "Amount empty count should be at least 1")

        Set parentStats = ..FindColumnByName(result.columns, "Parent")
        Do $$$AssertTrue($IsObject(parentStats), "Parent stats should exist")
        Do $$$AssertTrue(parentStats.populatedCount >= 1, "Parent populated count should be at least 1")
        Do $$$AssertTrue(parentStats.emptyCount >= 1, "Parent empty count should be at least 1")

        Set nameStats = ..FindColumnByName(result.columns, "Name")
        Do $$$AssertTrue($IsObject(nameStats), "Name stats should exist")
        Do $$$AssertTrue(nameStats.populatedPercent > 0, "Name populated percent should be greater than 0")
        Do $$$AssertTrue(nameStats.emptyPercent > 0, "Name empty percent should be greater than 0")
    } Catch ex {
        If childId2 '= "" {
            Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId2)
        }
        If childId1 '= "" {
            Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId1)
        }
        If parentId '= "" {
            Do ##class(esh.iris.entity.tests.SampleParent).%DeleteId(parentId)
        }
        Throw ex
    }
    If childId2 '= "" {
        Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId2)
    }
    If childId1 '= "" {
        Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId1)
    }
    If parentId '= "" {
        Do ##class(esh.iris.entity.tests.SampleParent).%DeleteId(parentId)
    }
}

Method TestGetPersistentClassEmptyRecords()
{
    Do ..InitRequestResponse()
    Set parentId = ""
    Set childId1 = ""
    Set childId2 = ""
    Try {
        Set parent = ##class(esh.iris.entity.tests.SampleParent).%New()
        Set parent.Name = "Empty Parent "_$J_"-"_$Random(10000)
        Set sc = parent.%Save()
        Do $$$AssertStatusOK(sc, "Saving empty parent failed")

        Set child1 = ##class(esh.iris.entity.tests.SampleChild).%New()
        Set child1.Name = "Filled Empty Test "_$J_"-"_$Random(10000)
        Set child1.Amount = 7
        Set child1.Parent = parent
        Set sc = child1.%Save()
        Do $$$AssertStatusOK(sc, "Saving filled child failed")

        Set child2 = ##class(esh.iris.entity.tests.SampleChild).%New()
        Set child2.Name = ""
        Set sc = child2.%Save()
        Do $$$AssertStatusOK(sc, "Saving empty child failed")

        Set parentId = parent.%Id()
        Set childId1 = child1.%Id()
        Set childId2 = child2.%Id()

        Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassEmptyRecords("esh.iris.entity.tests.SampleChild", "Name", 50, 0)
        Do $$$AssertTrue($IsObject(result), "Empty records response must be an object")
        Do $$$AssertEquals(result.className, "esh.iris.entity.tests.SampleChild", "Empty records class name mismatch")
        Do $$$AssertEquals(result.columnName, "Name", "Empty records column name mismatch")
        Do $$$AssertTrue($IsObject(result.items), "Empty records items must be a dynamic array")

        Set row = ..FindRowById(result.items, childId2)
        Do $$$AssertTrue($IsObject(row), "Row with empty Name should be returned")
        Do $$$AssertEquals(row.Name, "", "Returned row should have empty Name")
    } Catch ex {
        If childId2 '= "" {
            Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId2)
        }
        If childId1 '= "" {
            Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId1)
        }
        If parentId '= "" {
            Do ##class(esh.iris.entity.tests.SampleParent).%DeleteId(parentId)
        }
        Throw ex
    }
    If childId2 '= "" {
        Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId2)
    }
    If childId1 '= "" {
        Do ##class(esh.iris.entity.tests.SampleChild).%DeleteId(childId1)
    }
    If parentId '= "" {
        Do ##class(esh.iris.entity.tests.SampleParent).%DeleteId(parentId)
    }
}

Method TestGetPersistentClassEmptyRecordsInvalidColumn()
{
    Do ..InitRequestResponse()
    Set result = ##class(esh.iris.entity.api.impl).GetPersistentClassEmptyRecords("esh.iris.entity.tests.SampleChild", "DoesNotExist", 10, 0)
    Do $$$AssertTrue($IsObject(result), "Invalid column response must be an object")
    Do $$$AssertEquals(%response.Status, 400, "Invalid column should set 400")
}

}

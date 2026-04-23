Class HoleFoods.api.tests.UnitTests Extends %UnitTest.TestCase
{

Method InitRequestResponse() [ Private ]
{
    Set %response = ##class(%CSP.Response).%New()
    Set %request = ##class(%CSP.Request).%New()
    //Set %request.Secure = 0
    //Set %request.Application = "/holefoods/api"
    Set %request.CgiEnvs("SERVER_NAME") = "localhost"
    Set %request.CgiEnvs("SERVER_PORT") = "52773"
}

Method CreateTempProduct(ByRef sku As %String) As %DynamicObject [ Private ]
{
    Set sku = "TEST-"_$P($H,",")_"-"_$J_"-"_$Random(10000)
    Set payload = {}
    Set payload.SKU = sku
    Set payload.Name = "Unit Test Product"
    Set payload.Category = "Test"
    Set payload.Price = 9.99
    Quit ##class(HoleFoods.api.impl).CreateProduct(payload)
}

Method TestProductCRUD()
{
    Do ..InitRequestResponse()
    Set created = ..CreateTempProduct(.sku)
    Do $$$AssertTrue($IsObject(created), "Created product is missing")
    Do $$$AssertEquals(created.SKU, sku, "Created SKU mismatch")

    Set fetched = ##class(HoleFoods.api.impl).GetProduct(sku)
    Do $$$AssertTrue($IsObject(fetched), "Fetched product is missing")
    Do $$$AssertEquals(fetched.SKU, sku, "Fetched SKU mismatch")

    Set update = {}
    Set update.Name = "Updated Name"
    Set update.Price = 12.5
    Set updated = ##class(HoleFoods.api.impl).UpdateProduct(sku, update)
    Do $$$AssertEquals(updated.Name, "Updated Name", "Update did not persist")
    Do $$$AssertEquals(updated.Price, 12.5, "Updated price mismatch")
    //b "L"
    Set deleted = ##class(HoleFoods.api.impl).DeleteProduct(sku)
    Do $$$AssertTrue($IsObject(deleted), "Delete response should be an object")
    Do $$$AssertEquals(deleted.%Size(), 0, "Delete response should be empty")

    Set missing = ##class(HoleFoods.api.impl).GetProduct(sku)
    Do $$$AssertTrue($IsObject(missing), "Missing product should return object")
    Do $$$AssertEquals(missing.%Size(), 0, "Deleted product should be empty")
}

Method TestListProducts()
{
    Do ..InitRequestResponse()
    //B "L"
    Set created = ..CreateTempProduct(.sku)
    Do $$$AssertTrue($IsObject(created), "Created product is missing")

    Set list = ##class(HoleFoods.api.impl).ListProducts()
    Do $$$AssertTrue($IsObject(list), "List should be a JSON array")

    Set found = 0
    For i = 0:1:list.%Size()-1 {
        Set item = list.%Get(i)
        If $IsObject(item), item.SKU = sku {
            Set found = 1
        }
    }
    Do $$$AssertEquals(found, 1, "Created product not found in list")

    Do ##class(HoleFoods.api.impl).DeleteProduct(sku)
}

Method TestListOutlets()
{
    Do ..InitRequestResponse()
    Set outlet = ##class(HoleFoods.Outlet).%New()
    Set outlet.City = "Unit Test City"
    Set outlet.Type = "Retail"
    Set sc = outlet.%Save()
    Do $$$AssertStatusOK(sc, "Outlet save failed")

    Set list = ##class(HoleFoods.api.impl).ListOutlets()
    Do $$$AssertTrue($IsObject(list), "Outlets list should be a JSON array")

    Set found = 0
    For i = 0:1:list.%Size()-1 {
        Set item = list.%Get(i)
        If $IsObject(item), item.OutletId = outlet.%Id() {
            Set found = 1
        }
    }
    Do $$$AssertEquals(found, 1, "Outlet not found in list")

    Do outlet.%Delete()
}

Method TestListTransactions()
{
    Do ..InitRequestResponse()
    Set created = ..CreateTempProduct(.sku)
    Do $$$AssertTrue($IsObject(created), "Product create failed")

    Set outlet = ##class(HoleFoods.Outlet).%New()
    Set outlet.City = "Unit Test City"
    Set outlet.Type = "Retail"
    Set sc = outlet.%Save()
    Do $$$AssertStatusOK(sc, "Outlet save failed")

    Set tDate = $Piece($H, ",", 1)
    Set dateString = $ZDATE(tDate, 3)
    Set transaction = ##class(HoleFoods.Transaction).%New()
    Set transaction.Actual = 1
    Set transaction.DateOfSale = tDate
    Set transaction.Product = ##class(HoleFoods.Product).%OpenId(sku)
    Set transaction.Outlet = outlet
    Set transaction.AmountOfSale = 25.75
    Set transaction.UnitsSold = 3
    Set sc = transaction.%Save()
    Do $$$AssertStatusOK(sc, "Transaction save failed")

    Set found = 0
    Set list = ##class(HoleFoods.api.impl).ListTransactions(dateString, dateString, outlet.%Id(), sku)
    Do $$$AssertTrue($IsObject(list), "Transactions list should be a JSON array")
    For i = 0:1:list.%Size()-1 {
        Set item = list.%Get(i)
        If $IsObject(item), item.TransactionId = transaction.%Id() {
            Set found = 1
        }
    }
    Do $$$AssertEquals(found, 1, "Transaction not found")

    Do transaction.%Delete()
    Do outlet.%Delete()
    Do ##class(HoleFoods.Product).%DeleteId(sku)
}

}

Class esh.in.explorer.tests.runner Extends %RegisteredObject
{

ClassMethod RunTests() As %Status
{
    Set ^UnitTestRoot = "/home/irisowner/dev/tests"
    Set sc = ##class(%UnitTest.Manager).RunTest("esh/in/explorer/tests", "/loadudl /nodelete")
    Quit sc
}

}

Class esh.in.explorer.api.spec Extends %REST.Spec
{

Parameter HandleCorsRequest = 1;

Parameter CONTENTTYPE = "application/json";

Parameter ExposeServerExceptions = 1;

XData OpenAPI [ MimeType = application/json ]
{
{
  "swagger": "2.0",
  "info": {
    "title": "LinkedIn Connections API",
    "version": "1.0.0",
    "description": "REST API for storing and exploring LinkedIn connections in InterSystems IRIS."
  },
  "basePath": "/in-explorer/api",
  "consumes": [
    "application/json"
  ],
  "produces": [
    "application/json"
  ],
  "securityDefinitions": {
    "bearerAuth": {
      "type": "apiKey",
      "name": "Authorization",
      "in": "header",
      "description": "Bearer token authentication."
    }
  },
  "security": [
    {
      "bearerAuth": []
    }
  ],
  "paths": {
    "/_spec": {
      "get": {
        "summary": "Get OpenAPI spec",
        "operationId": "GetSpec",
        "security": [],
        "responses": {
          "200": {
            "description": "Swagger spec JSON",
            "schema": { "type": "object" }
          }
        }
      }
    },
    "/auth/google": {
      "post": {
        "summary": "Sign in with Google",
        "operationId": "AuthGoogle",
        "security": [],
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "schema": { "$ref": "#/definitions/GoogleAuthRequest" }
          }
        ],
        "responses": {
          "200": {
            "description": "Authenticated",
            "schema": { "$ref": "#/definitions/AuthState" }
          },
          "400": {
            "description": "Invalid request"
          },
          "401": {
            "description": "Invalid Google credential"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    },
    "/auth/me": {
      "get": {
        "summary": "Get current authentication state",
        "operationId": "AuthMe",
        "security": [],
        "responses": {
          "200": {
            "description": "Current auth state",
            "schema": { "$ref": "#/definitions/AuthState" }
          }
        }
      }
    },
    "/auth/logout": {
      "post": {
        "summary": "Log out current session",
        "operationId": "AuthLogout",
        "security": [],
        "responses": {
          "200": {
            "description": "Logged out",
            "schema": { "$ref": "#/definitions/AuthState" }
          }
        }
      }
    },
    "/connections": {
      "get": {
        "summary": "List connections",
        "operationId": "ListConnections",
        "parameters": [
          { "name": "search", "in": "query", "type": "string" },
          { "name": "city", "in": "query", "type": "string" },
          { "name": "industry", "in": "query", "type": "string" },
          { "name": "company", "in": "query", "type": "string" },
          {
            "name": "role",
            "in": "query",
            "type": "string",
            "enum": ["investor", "founder", "operator", "engineer", "designer", "product", "sales", "marketing", "recruiter", "student", "other"]
          },
          { "name": "tag", "in": "query", "type": "string" },
          {
            "name": "sort",
            "in": "query",
            "type": "string",
            "enum": ["recent", "name", "company"],
            "default": "recent"
          },
          {
            "name": "page",
            "in": "query",
            "type": "integer",
            "format": "int32",
            "minimum": 1,
            "default": 1
          },
          {
            "name": "pageSize",
            "in": "query",
            "type": "integer",
            "format": "int32",
            "minimum": 1,
            "maximum": 200,
            "default": 50
          }
        ],
        "responses": {
          "200": {
            "description": "Paginated list",
            "schema": { "$ref": "#/definitions/ConnectionPage" }
          },
          "401": {
            "description": "Authentication required"
          },
          "500": {
            "description": "Server error"
          }
        }
      },
      "post": {
        "summary": "Upsert one or more connections",
        "operationId": "UpsertConnections",
        "parameters": [
          {
            "name": "body",
            "in": "body",
            "required": true,
            "schema": { "$ref": "#/definitions/ConnectionOrArray" }
          }
        ],
        "responses": {
          "200": {
            "description": "Upserted",
            "schema": { "$ref": "#/definitions/UpsertResponse" }
          },
          "400": {
            "description": "Invalid request"
          },
          "401": {
            "description": "Authentication required"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    },
    "/connections/import-csv": {
      "post": {
        "summary": "Import connections from LinkedIn CSV",
        "operationId": "ImportConnectionsCsv",
        "parameters": [
          {
            "name": "path",
            "in": "query",
            "type": "string",
            "description": "Optional absolute path to CSV file. Defaults to /home/irisowner/dev/data/Connections.csv."
          }
        ],
        "responses": {
          "200": {
            "description": "Import summary",
            "schema": { "$ref": "#/definitions/ImportSummary" }
          },
          "401": {
            "description": "Authentication required"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    },
    "/connections/facets": {
      "get": {
        "summary": "Counts for sidebar filters",
        "operationId": "GetConnectionFacets",
        "parameters": [
          { "name": "search", "in": "query", "type": "string" }
        ],
        "responses": {
          "200": {
            "description": "Facet counts",
            "schema": { "$ref": "#/definitions/Facets" }
          },
          "401": {
            "description": "Authentication required"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    },
    "/connections/{id}": {
      "get": {
        "summary": "Get one connection",
        "operationId": "GetConnection",
        "parameters": [
          { "name": "id", "in": "path", "required": true, "type": "string" }
        ],
        "responses": {
          "200": {
            "description": "Found",
            "schema": { "$ref": "#/definitions/Connection" }
          },
          "401": {
            "description": "Authentication required"
          },
          "404": {
            "description": "Not found"
          }
        }
      },
      "patch": {
        "summary": "Patch a connection",
        "operationId": "PatchConnection",
        "parameters": [
          { "name": "id", "in": "path", "required": true, "type": "string" },
          {
            "name": "body",
            "in": "body",
            "required": true,
            "schema": { "$ref": "#/definitions/ConnectionPatch" }
          }
        ],
        "responses": {
          "200": {
            "description": "Updated",
            "schema": { "$ref": "#/definitions/Connection" }
          },
          "400": {
            "description": "Invalid request"
          },
          "401": {
            "description": "Authentication required"
          },
          "404": {
            "description": "Not found"
          },
          "500": {
            "description": "Server error"
          }
        }
      },
      "delete": {
        "summary": "Delete a connection",
        "operationId": "DeleteConnection",
        "parameters": [
          { "name": "id", "in": "path", "required": true, "type": "string" }
        ],
        "responses": {
          "204": {
            "description": "Deleted"
          },
          "401": {
            "description": "Authentication required"
          },
          "404": {
            "description": "Not found"
          },
          "500": {
            "description": "Server error"
          }
        }
      }
    }
  },
  "definitions": {
    "GoogleAuthRequest": {
      "type": "object",
      "required": ["credential"],
      "properties": {
        "credential": { "type": "string" },
        "csrfToken": { "type": "string", "description": "Optional copy of the GIS g_csrf_token cookie value." }
      }
    },
    "AuthUser": {
      "type": "object",
      "required": ["sub"],
      "properties": {
        "sub": { "type": "string" },
        "email": { "type": "string", "format": "email", "x-nullable": true },
        "name": { "type": "string", "x-nullable": true },
        "picture": { "type": "string", "format": "uri", "x-nullable": true },
        "hd": { "type": "string", "x-nullable": true },
        "expiresAt": { "type": "integer", "format": "int64" }
      }
    },
    "AuthState": {
      "type": "object",
      "required": ["authenticated"],
      "properties": {
        "authenticated": { "type": "boolean" },
        "sessionToken": { "type": "string", "x-nullable": true },
        "user": { "$ref": "#/definitions/AuthUser", "x-nullable": true }
      }
    },
    "ConnectionOrArray": {
      "type": "object",
      "description": "Accepts either a single Connection object or an array of Connection objects."
    },
    "RoleTag": {
      "type": "string",
      "enum": ["investor", "founder", "operator", "engineer", "designer", "product", "sales", "marketing", "recruiter", "student", "other"]
    },
    "Connection": {
      "type": "object",
      "required": ["id", "firstName", "lastName", "url"],
      "properties": {
        "id": { "type": "string", "example": "vittoria-braggion-17a172200" },
        "firstName": { "type": "string", "example": "Vittoria" },
        "lastName": { "type": "string", "example": "Braggion" },
        "url": { "type": "string", "format": "uri", "example": "https://www.linkedin.com/in/vittoria-braggion-17a172200" },
        "email": { "type": "string", "format": "email", "x-nullable": true },
        "company": { "type": "string", "x-nullable": true, "example": "Docebo" },
        "position": { "type": "string", "x-nullable": true, "example": "Business Development Representative" },
        "connectedOn": { "type": "string", "format": "date", "x-nullable": true, "example": "2026-04-18" },
        "city": { "type": "string", "x-nullable": true, "example": "Milan" },
        "country": { "type": "string", "x-nullable": true, "example": "Italy" },
        "industry": { "type": "string", "x-nullable": true, "example": "Education" },
        "roleTags": { "type": "array", "items": { "$ref": "#/definitions/RoleTag" } },
        "tags": { "type": "array", "items": { "type": "string" } },
        "notes": { "type": "string", "x-nullable": true }
      }
    },
    "ConnectionPatch": {
      "type": "object",
      "properties": {
        "firstName": { "type": "string" },
        "lastName": { "type": "string" },
        "url": { "type": "string", "format": "uri" },
        "email": { "type": "string", "format": "email", "x-nullable": true },
        "company": { "type": "string", "x-nullable": true },
        "position": { "type": "string", "x-nullable": true },
        "connectedOn": { "type": "string", "format": "date", "x-nullable": true },
        "city": { "type": "string", "x-nullable": true },
        "country": { "type": "string", "x-nullable": true },
        "industry": { "type": "string", "x-nullable": true },
        "roleTags": { "type": "array", "items": { "$ref": "#/definitions/RoleTag" } },
        "tags": { "type": "array", "items": { "type": "string" } },
        "notes": { "type": "string", "x-nullable": true }
      }
    },
    "ConnectionPage": {
      "type": "object",
      "required": ["items", "total", "page", "pageSize"],
      "properties": {
        "items": { "type": "array", "items": { "$ref": "#/definitions/Connection" } },
        "total": { "type": "integer", "format": "int32" },
        "page": { "type": "integer", "format": "int32" },
        "pageSize": { "type": "integer", "format": "int32" }
      }
    },
    "FacetCount": {
      "type": "object",
      "required": ["value", "count"],
      "properties": {
        "value": { "type": "string" },
        "count": { "type": "integer", "format": "int32" }
      }
    },
    "RoleFacetCount": {
      "type": "object",
      "required": ["value", "count"],
      "properties": {
        "value": { "$ref": "#/definitions/RoleTag" },
        "count": { "type": "integer", "format": "int32" }
      }
    },
    "Facets": {
      "type": "object",
      "required": ["cities", "industries", "companies", "roles", "tags"],
      "properties": {
        "cities": { "type": "array", "items": { "$ref": "#/definitions/FacetCount" } },
        "industries": { "type": "array", "items": { "$ref": "#/definitions/FacetCount" } },
        "companies": { "type": "array", "items": { "$ref": "#/definitions/FacetCount" } },
        "roles": { "type": "array", "items": { "$ref": "#/definitions/RoleFacetCount" } },
        "tags": { "type": "array", "items": { "$ref": "#/definitions/FacetCount" } }
      }
    },
    "UpsertResponse": {
      "type": "object",
      "properties": {
        "upserted": { "type": "integer", "format": "int32" }
      }
    },
    "ImportError": {
      "type": "object",
      "properties": {
        "line": { "type": "integer", "format": "int32" },
        "message": { "type": "string" }
      }
    },
    "ImportSummary": {
      "type": "object",
      "properties": {
        "path": { "type": "string" },
        "status": { "type": "string", "enum": ["ok", "partial", "error"] },
        "processed": { "type": "integer", "format": "int32" },
        "imported": { "type": "integer", "format": "int32" },
        "inserted": { "type": "integer", "format": "int32" },
        "updated": { "type": "integer", "format": "int32" },
        "skipped": { "type": "integer", "format": "int32" },
        "failed": { "type": "integer", "format": "int32" },
        "errors": {
          "type": "array",
          "items": { "$ref": "#/definitions/ImportError" }
        }
      }
    }
  }
}
}

}

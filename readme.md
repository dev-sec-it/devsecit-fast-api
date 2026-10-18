# 🛡️ DEV SEC IT — Fast API Engine & Control Panel
> High-performance, stateless REST API server and desktop management engine with native dual MySQL & PostgreSQL database drivers.

**Organization**: [DEV SEC IT](https://github.com/dev-sec-it) | **Version**: 2.0.0 | **License**: MIT

---

### ✨ Key Highlights
- ⚡ **Ultra-Fast & Memory Safe**: Built with pure Rust, Axum, and SQLx.
- 🗄️ **Dual Database Support**: Seamless on-demand pooling for MySQL and PostgreSQL.
- 🔒 **Encrypted Token Security**: Zero-trust multi-tenant credential verification with live revocation and rotation.
- 🛡️ **Structured Condition Predicates**: Parameterized SQL queries eliminate injection structurally.
- 📦 **Transactions & Bcrypt**: Full atomic batch operations and native bcrypt password hashing.
- 🖥️ **Cross-Platform**: Complete support for Linux servers (Systemd daemon) and Windows Desktop GUI.

---

## 🚀 Get Started

### Linux Server
```bash
git clone https://github.com/dev-sec-it/devsecit-fast-api
cd devsecit-fast-api/linux
chmod +x ./*
./deploy.sh
```

### Windows
```text
Double click on windows.exe to install
```

## Check health 

```
http://[IP_ADDRESS]:8899/health
```

---

## Authentication & Headers

Every API request requires the `Content-Type` header and a dynamic **Bearer Token** passed in the `Authorization` header.

### Required Headers
```http
Content-Type: application/json
Authorization: Bearer YOUR_GENERATED_TOKEN
``` 

### Token Generation (`POST /token` or `POST /gen_token`)
Token issuance is POST-only with a JSON payload (`GET` returns `405 Method Not Allowed`, rate-limited to 20 req/min).

```http
POST /token
Content-Type: application/json

{
    "db_name": "your_db",
    "db_pass": "your_password",
    "user": "your_user",
    "driver": "mysql",
    "expiry": 7
}
```

**Response:**
```json
{
    "status": "success",
    "code": 200,
    "token": "<YOUR_GENERATED_TOKEN>",
    "driver": "mysql"
}
```

> [!IMPORTANT]
> - Do not pass tokens inside the JSON request body. Body tokens will be rejected with HTTP 401.
> - Ensure token expiry has not passed (`d-m-Y` comparison).
> - Presenting a revoked token will return `401 {"error_code": "TOKEN_REVOKED"}`.

---

## Condition Syntax & Rules

String conditions are disabled. All conditions must be structured JSON objects and are evaluated with bound parameters:

```jsonc
{ "email": "john@example.com" }                      // Equality (=)
{ "age": { "op": ">=", "value": 18 } }                // Comparison (=, !=, <, <=, >, >=, like)
{ "id": { "op": "in", "value": [1, 2, 3] } }          // Set membership (in, not_in)
{ "deleted_at": { "op": "is_null" } }                 // Null check (is_null, is_not_null)
{ "$or": true, "email": "a@b.c", "role": "admin" }   // Join clauses with OR
```

- Any attempt to send a raw SQL string condition returns `400 {"error_code": "RAW_SQL_DISABLED"}`.
- Reads (`GET`, `GET_SELECTED`) and mutations (`UPDATE`, `DELETE`) require a non-empty condition. An empty condition returns `400 {"error_code": "CONDITION_REQUIRED"}`.
- Type coercion on INT columns is strictly validated. Sending non-integer strings to integer columns returns `400 {"error_code": "INVALID_CONDITION_VALUE"}`.

---

## API Methods Reference

---

### 1. Insert Data (`INSERT` / `PUT`)
Inserts a new record into the specified table. If the table or columns do not exist, they are auto-created. If an optional `condition` object is supplied, the API checks whether matching data exists before inserting.

**Request Body (JSON):**
```json
{
    "method": "INSERT",
    "table": "users",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "1234567890",
    "condition": { "email": "john@example.com" }
}
```

**Success Response (Status 200):**
```json
{
    "err": false,
    "status": 200,
    "table": "users",
    "msg": "Data added!",
    "code": 200,
    "id": 15,
    "data": [
        {
            "id": 15,
            "name": "John Doe",
            "email": "john@example.com",
            "phone": "1234567890",
            "date": "18-10-2026",
            "time": "11:05:00 AM"
        }
    ]
}
```

---

### 2. Get Data (`GET`)
Fetches records matching the mandatory condition. Supports pagination and opt-in column redaction.

**Request Body (JSON):**
```json
{
    "method": "GET",
    "table": "users",
    "condition": { "status": "active" },
    "limit": 50,
    "offset": 0,
    "redact": ["password"]
}
```

**Success Response (Status 200):**
```json
{
    "status": 200,
    "table": "users",
    "data": [
        {
            "id": 1,
            "name": "John Doe",
            "email": "john@example.com",
            "status": "active"
        }
    ],
    "limit": 50,
    "offset": 0,
    "has_more": false
}
```

---

### 3. Get Selected Data (`GET_SELECTED`)
Fetches records matching the condition with field projection.

**Request Body (JSON):**
```json
{
    "method": "GET_SELECTED",
    "table": "users",
    "condition": { "status": "active" },
    "fields": "id, name, email",
    "limit": 50,
    "offset": 0
}
```

---

### 4. Update Data (`UPDATE`)
Updates records matching the condition.

**Request Body (JSON):**
```json
{
    "method": "UPDATE",
    "table": "users",
    "condition": { "id": 1 },
    "name": "John Updated",
    "phone": "9876543210"
}
```

**Success Response (Status 200):**
```json
{
    "err": false,
    "status": 200,
    "table": "users",
    "affected_rows": 1,
    "msg": "Data updated!",
    "code": 200
}
```
*(If 0 rows matched, returns `200` with `affected_rows: 0`).*

---

### 5. Delete Data (`DELETE`)
Deletes records matching the condition.

**Request Body (JSON):**
```json
{
    "method": "DELETE",
    "table": "users",
    "condition": { "id": 1 }
}
```

**Success Response (Status 200):**
```json
{
    "err": false,
    "status": 200,
    "table": "users",
    "affected_rows": 1,
    "msg": "Data deleted!",
    "code": 200
}
```

---

### 6. Atomic Transactions (`TRANSACTION`)
Executes an atomic batch of up to 100 operations. If any operation fails, the entire batch rolls back automatically.

**Request Body (JSON):**
```json
{
    "method": "TRANSACTION",
    "operations": [
        { "method": "INSERT", "table": "orders", "data": { "user_id": 1, "total": 99.99 } },
        { "method": "UPDATE", "table": "users", "condition": { "id": 1 }, "data": { "has_orders": true } }
    ]
}
```

**Success Response (Status 200):**
```json
{
    "status": 200,
    "err": false,
    "committed": true,
    "operations_count": 2,
    "results": [...]
}
```

---

### 7. Hashing Helpers (`HASH_VALUE` / `HASH_COMPARE`)
Provides server-side bcrypt hashing so plaintext secrets never touch raw tables.

**Hash Value:**
```json
{ "method": "HASH_VALUE", "value": "my_secret_password", "cost": 12 }
```
`-> { "err": false, "hash": "$2b$12$...", "algorithm": "bcrypt", "cost": 12 }`

**Compare Hash:**
```json
{ "method": "HASH_COMPARE", "value": "my_secret_password", "hash": "$2b$12$..." }
```
`-> { "err": false, "matches": true }`

---

### 8. Rotate Token (`ROTATE_TOKEN`)
Immediately revokes the currently presented token and issues a new replacement token.

**Request Body (JSON):**
```json
{ "method": "ROTATE_TOKEN", "expiry": 7 }
```
`-> { "status": 200, "err": false, "token": "<NEW_TOKEN>", "revoked_salt": "salt_..." }`

---

### 9. Inspect Table Schema (`GET_TABLE`)
Retrieves the schema and column definitions for a given table.

```json
{ "method": "GET_TABLE", "table": "users" }
```

---

### 10. List Database Tables (`GET_DB`)
Lists all tables within the active database in standard array-of-objects format.

```json
{ "method": "GET_DB" }
```
**Response:**
```json
{
    "status": 200,
    "table": "my_db",
    "data": [
        { "table": "users" },
        { "table": "orders" }
    ]
}
```

---

### 11. Add Columns (`ADD_COLUMNS`)
Adds column definitions to an existing table and verifies existence.

```json
{
    "method": "ADD_COLUMNS",
    "table": "users",
    "columns": ["age INT", "bio TEXT"]
}
```
**Response:**
```json
{
    "status": 200,
    "err": false,
    "table": "users",
    "created": ["age", "bio"],
    "existing": []
}
```

---

## Standard Error Codes

All failures return HTTP 4xx/5xx status codes with standard machine-readable `error_code` fields:

| Code | Status | Meaning |
|---|---|---|
| `RAW_SQL_DISABLED` | 400 | String condition provided instead of JSON object |
| `CONDITION_REQUIRED` | 400 | Non-empty condition required for read/mutation |
| `INVALID_CONDITION` | 400 | Malformed predicate or unsupported operator |
| `INVALID_CONDITION_VALUE` | 400 | Type mismatch on numeric/boolean column |
| `INVALID_IDENTIFIER` | 400 | Table or column name violates naming pattern |
| `INVALID_PAGINATION` | 400 | Offset passed without limit or negative limit |
| `TABLE_NOT_FOUND` | 404 | Table does not exist in schema |
| `COLUMN_NOT_FOUND` | 400 | Column does not exist in table |
| `TOKEN_EXPIRED` | 401 | Token expiration timestamp has elapsed |
| `TOKEN_REVOKED` | 401 | Token salt was revoked via `ROTATE_TOKEN` |
| `METHOD_NOT_ALLOWED` | 405 | GET request made on POST-only endpoint |
| `CONNECTION_ERROR` | 503 | Database unreachable with token credentials |

# DevSecIt v2 API Documentation


## Authentication & Headers

Every API request requires the `Content-Type` header and a dynamic **Bearer Token** passed in the `Authorization` header.

### Required Headers
```http
Content-Type: application/json
Authorization: Bearer YOUR_GENERATED_TOKEN
``` 

You can generate tokens via `gen_token`:
```http
GET /gen_token?db_name=your_db&db_pass=your_password&user=your_user&expiry=7
```
**Response:**
```json
{
    "status": "success",
    "code": "200",
    "token": "salt_1700000000/aWW99kYg==/iWW91clYXNz.../oMjgtAtMjAyNg==/uWW9l91c2Vy..."
}
```

> [!IMPORTANT]
> - Do not pass tokens inside the JSON request body. Body tokens will be rejected with HTTP 401.
> - Ensure token expiry has not passed (`d-m-Y` comparison).

---

## Security & Condition Constraints

The API strictly prohibits condition injection and tautological bypass queries. The following condition values are blocked by the firewall:
- `1=1`
- `id>0` / `id > '0'`
- `true`
- Empty or whitespace conditions for destructive methods (`GET`, `UPDATE`, `DELETE`)

---

## API Methods Reference

---

### 1. Insert Data (`INSERT` / `PUT`)
Inserts a new record into the specified table. If an optional `condition` is supplied, the API checks whether matching data exists before inserting.

**Request Body (JSON):**
```json
{
    "method": "INSERT",
    "table": "users",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "1234567890",
    "condition": "email='john@example.com'"
}
```

**Success Response (Status 200 - Inserted):**
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
            "id": "15",
            "name": "John Doe",
            "email": "john@example.com",
            "phone": "1234567890",
            "date": "04-10-2026",
            "time": "11:05:00 AM"
        }
    ]
}
```

**Conflict Response (Status 201 - Already Exists):**
```json
{
    "status": 201,
    "table": "users",
    "msg": "Data already exists",
    "data": {
        "id": "12",
        "name": "John Doe",
        "email": "john@example.com"
    }
}
```

---

### 2. Get Data (`GET`)
Fetches all matching records from a table. The `password` field is automatically redacted from the response for security.

**Request Body (JSON):**
```json
{
    "method": "GET",
    "table": "users",
    "condition": "status='active'"
}
```

**Success Response (Status 200):**
```json
{
    "status": 200,
    "table": "users",
    "data": [
        {
            "id": "1",
            "name": "John Doe",
            "email": "john@example.com",
            "status": "active"
        }
    ]
}
```

---

### 3. Get Selected Data (`GET_SELECTED`)
Fetches records matching the condition with optional field column projection.

**Request Body (JSON):**
```json
{
    "method": "GET_SELECTED",
    "table": "users",
    "condition": "status='active'",
    "fields": "id, name, email"
}
```

**Success Response (Status 200):**
```json
{
    "status": 200,
    "table": "users",
    "data": [
        {
            "id": "1",
            "name": "John Doe",
            "email": "john@example.com"
        }
    ]
}
```

---

### 4. Update Data (`UPDATE`)
Updates records matching the condition. If the optional `act` parameter is provided and no matching rows are modified, the endpoint automatically falls back to insert the record.

**Request Body (JSON):**
```json
{
    "method": "UPDATE",
    "table": "users",
    "condition": "id='1'",
    "name": "John Updated",
    "phone": "9876543210"
}
```

**Success Response (Status 200 - Updated):**
```json
{
    "err": false,
    "table": "users",
    "msg": "Data updated!",
    "code": 200
}
```

**Upsert Response with `act` (Status 200 - Auto-Inserted):**
```json
{
    "err": false,
    "table": "users",
    "status": 200,
    "msg": "Data added!",
    "code": 200,
    "id": 16,
    "data": [
        {
            "id": "16",
            "name": "John Updated",
            "phone": "9876543210"
        }
    ]
}
```

---

### 5. Delete Data (`DELETE`)
Deletes records matching the specified condition.

**Request Body (JSON):**
```json
{
    "method": "DELETE",
    "table": "users",
    "condition": "id='1'"
}
```

**Success Response (Status 200):**
```json
{
    "err": false,
    "table": "users",
    "msg": "Data deleted!",
    "code": 200
}
```

---

### 6. Upload Photo & Documents (`UPLOAD_PHOTO` / `UPLOAD_ME`)
Uploads base64-encoded files securely. 

**Allowed Extensions:** `jpg, jpeg, png, webp, gif, svg, pdf, doc, docx, csv, xlsx`

**Request Body (JSON):**
```json
{
    "method": "UPLOAD_PHOTO",
    "ext": "png",
    "document": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
}
```

**Success Response (Status 200):**
```json
{
    "status": 200,
    "err": false,
    "uri": "https://api.yourdomain.com/uploads/0d9c488349/1700000000_a1b2c3d4.png"
}
```

---

### 7. Inspect Table Schema (`GET_TABLE`)
Retrieves the schema and column definitions for a given table via `DESCRIBE`.

**Request Body (JSON):**
```json
{
    "method": "GET_TABLE",
    "table": "users"
}
```

**Success Response (Status 200):**
```json
{
    "status": 200,
    "table": "users",
    "data": [
        {
            "Field": "id",
            "Type": "int(11)",
            "Null": "NO",
            "Key": "PRI",
            "Default": null,
            "Extra": "auto_increment"
        },
        {
            "Field": "name",
            "Type": "text",
            "Null": "YES",
            "Key": "",
            "Default": null,
            "Extra": ""
        }
    ]
}
```

---

### 8. List Database Tables (`GET_DB`)
Lists all tables within the currently authenticated database.

**Request Body (JSON):**
```json
{
    "method": "GET_DB"
}
```

**Success Response (Status 200):**
```json
{
    "status": 200,
    "table": "database_name",
    "data": [
        ["users"],
        ["orders"],
        ["products"]
    ]
}
```

---

### 9. Create Table (`CREATE_TABLE`)
Creates a new MySQL table with an `id INT NOT NULL AUTO_INCREMENT PRIMARY KEY`.

**Request Body (JSON):**
```json
{
    "method": "CREATE_TABLE",
    "table": "customers"
}
```

**Success Response (Status 200):**
```json
{
    "status": 200,
    "err": false,
    "table": "customers",
    "msg": "Table created!"
}
```

---

### 10. Add Columns to Table (`ADD_COLUMNS`)
Adds column definitions to an existing table via `ALTER TABLE`.

**Request Body (JSON):**
```json
{
    "method": "ADD_COLUMNS",
    "table": "customers",
    "columns": [
        "`address` TEXT DEFAULT NULL",
        "`city` VARCHAR(100) DEFAULT NULL"
    ]
}
```
*(Accepts either a JSON array or a JSON-encoded string array).*

**Success Response (Status 200):**
```json
{
    "status": 200,
    "err": false,
    "table": "customers",
    "msg": "Columns added!"
}
```

---

## Global Error Response Formats

Whenever an exception, validation error, or fatal error occurs, the API returns a structured JSON payload:

### Unauthorized Error (401)
```json
{
    "status": "error",
    "message": "Authorization header missing",
    "code": 401
}
```

### Invalid Condition Error (400)
```json
{
    "status": 400,
    "table": "users",
    "msg": "Invalid condition. You should not use this kind of condition!",
    "code": 400
}
```

### Runtime Exception Trap (200 JSON Payload)
```json
{
    "status": false,
    "error_type": "EXCEPTION",
    "message": "Error details",
    "file": "/path/to/file",
    "line": 45
}
```

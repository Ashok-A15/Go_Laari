# GoLorry Backend API Documentation

This API handles the secure management of Owners and Drivers for the GoLorry logistics platform.

## Base URL
The API is deployed as a Firebase Cloud Function:
`https://<region>-<project-id>.cloudfunctions.net/api`

## Authentication
All protected routes require a Firebase ID Token in the Authorization header:
`Authorization: Bearer <ID_TOKEN>`

---

## 1. Create Driver
**Endpoint**: `POST /owner/create-driver`
**Role**: Owner Only

### Request
```json
{
  "name": "Amit Sharma",
  "email": "amit.driver@golorry.com",
  "password": "securepassword123",
  "phone": "9876543210",
  "vehicleNumber": "KA 01 AB 5678"
}
```

### Response (201 Created)
```json
{
  "message": "Driver account created successfully",
  "driver": {
    "uid": "abc123driverUid",
    "email": "amit.driver@golorry.com",
    "name": "Amit Sharma"
  }
}
```

---

## 2. Get All Drivers
**Endpoint**: `GET /owner/drivers`
**Role**: Owner Only

### Response (200 OK)
```json
{
  "drivers": [
    {
      "uid": "abc123driverUid",
      "ownerId": "ownerUid456",
      "name": "Amit Sharma",
      "email": "amit.driver@golorry.com",
      "status": "active",
      "vehicleNumber": "KA 01 AB 5678"
    }
  ]
}
```

---

## 3. Update Driver Status (Deactivate)
**Endpoint**: `PATCH /owner/drivers/:driverId/status`
**Role**: Owner Only

### Request
```json
{
  "status": "inactive"
}
```

### Response (200 OK)
```json
{
  "message": "Driver marked as inactive"
}
```

---

## 4. Get Driver Profile
**Endpoint**: `GET /driver/profile`
**Role**: Driver Only

### Response (200 OK)
```json
{
  "uid": "abc123driverUid",
  "ownerId": "ownerUid456",
  "name": "Amit Sharma",
  "email": "amit.driver@golorry.com",
  "status": "active",
  "vehicleNumber": "KA 01 AB 5678"
}
```

# Calendar Synchronization Smart Contract

A Clarity smart contract for managing and synchronizing calendar events on the Stacks blockchain.

## Overview

This smart contract enables users to create, manage, and share calendar events on the blockchain. It provides features such as event creation, modification, deletion, and sharing capabilities with proper access controls. The contract ensures data integrity by validating inputs and maintaining proper authorization checks.

## Features

- **Event Management**: Create, update, and delete calendar events
- **Access Control**: Public/private events with granular sharing permissions
- **Input Validation**: Ensures proper data formats and time sequencing
- **Blockchain Timestamps**: Uses blockchain timestamps for reliable time tracking
- **User-friendly IDs**: Auto-increments event IDs for easy reference

## Functions

### Public Functions

#### Event Management

- **create-event**: Create a new calendar event
  ```clarity
  (create-event title description start-time end-time location is-public)
  ```
  - Returns: `(ok event-id)` on success, or an error code

- **update-event**: Modify an existing event
  ```clarity
  (update-event event-id title description start-time end-time location is-public)
  ```
  - Returns: `(ok true)` on success, or an error code

- **delete-event**: Remove an event
  ```clarity
  (delete-event event-id)
  ```
  - Returns: `(ok true)` on success, or an error code

#### Sharing Management

- **share-event**: Share a specific event with another user with granular permissions
  ```clarity
  (share-event event-id recipient can-view can-edit can-delete)
  ```
  - Returns: `(ok true)` on success, or an error code

### Read-Only Functions

- **get-event**: View details of a specific event
  ```clarity
  (get-event event-id)
  ```
  - Returns: `(ok {event-data})` on success, or an error code

- **get-user-event-count**: Get the number of events owned by a user
  ```clarity
  (get-user-event-count user)
  ```
  - Returns: `(ok {count: uint})` with the event count

- **get-event-permission**: Check sharing permissions for a specific event
  ```clarity
  (get-event-permission event-id user)
  ```
  - Returns: `(ok {permission-data})` with view/edit/delete permission flags

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: User doesn't have permission for this operation
- `ERR-EVENT-NOT-FOUND (u101)`: The specified event doesn't exist
- `ERR-INVALID-TIME (u102)`: Invalid time parameters (end must be after start)
- `ERR-INVALID-INPUT (u103)`: Invalid input parameters (empty strings, etc.)

## Data Structures

### Event

```clarity
{
  owner: principal,
  title: (string-utf8 100),
  description: (string-utf8 500),
  start-time: uint,
  end-time: uint,
  location: (string-utf8 100),
  is-public: bool,
  last-modified: uint
}
```

### Event Permission

```clarity
{
  can-view: bool,
  can-edit: bool,
  can-delete: bool
}
```

## Usage Examples

### Creating an Event

```clarity
(contract-call? .calendar-sync create-event 
  "Team Meeting" 
  "Weekly sync meeting with the development team" 
  u1685102400 
  u1685106000 
  "Conference Room A" 
  false)
```

### Sharing an Event with Another User

```clarity
;; Give view-only access
(contract-call? .calendar-sync share-event 
  u1
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM 
  true false false)

;; Give full access
(contract-call? .calendar-sync share-event
  u1
  'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
  true true true)
```

### Getting Event Details

```clarity
(contract-call? .calendar-sync get-event u1)
```

### Checking Event Permissions

```clarity
(contract-call? .calendar-sync get-event-permission u1 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Security Considerations

- All event modifications require proper authorization
- Time values are validated to ensure integrity
- String inputs are validated to ensure they're not empty
- Fine-grained permissions model for access control
- Events track last modification time for audit purposes
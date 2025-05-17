# Calendar Synchronization Smart Contract

A Clarity smart contract for managing and synchronizing calendar events on the Stacks blockchain.

## Overview

This smart contract enables users to create, manage, and share calendar events on the blockchain. It provides features such as event creation, modification, deletion, and sharing capabilities with proper access controls. The contract ensures data integrity by preventing scheduling conflicts and maintaining proper authorization checks.

## Features

- **Event Management**: Create, update, and delete calendar events
- **Access Control**: Public/private events with granular sharing permissions
- **Conflict Detection**: Prevents double-booking by checking for time overlaps
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

#### Calendar Sharing

- **grant-calendar-access**: Share your calendar with another user
  ```clarity
  (grant-calendar-access accessor can-read can-write)
  ```
  - Returns: `(ok true)` on success

- **revoke-calendar-access**: Remove sharing permissions
  ```clarity
  (revoke-calendar-access accessor)
  ```
  - Returns: `(ok true)` on success

### Read-Only Functions

- **get-event**: View details of a specific event
  ```clarity
  (get-event event-id)
  ```
  - Returns: `(ok {event-data})` on success, or an error code

- **get-user-events**: List all events for a user
  ```clarity
  (get-user-events user)
  ```
  - Returns: `(ok [event-ids])` filtered by access permissions

- **check-calendar-access**: Check sharing permissions
  ```clarity
  (check-calendar-access owner accessor)
  ```
  - Returns: `(ok {access-data})` with read/write permission flags

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: User doesn't have permission for this operation
- `ERR-EVENT-NOT-FOUND (u101)`: The specified event doesn't exist
- `ERR-INVALID-TIME (u102)`: Invalid time parameters (end must be after start)
- `ERR-EVENT-OVERLAP (u103)`: Event conflicts with an existing event
- `ERR-INVALID-EVENT-ID (u104)`: The event ID is not valid

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

### Access Permission

```clarity
{
  can-read: bool,
  can-write: bool
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

### Sharing Calendar with Another User

```clarity
;; Give read-only access
(contract-call? .calendar-sync grant-calendar-access 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM true false)

;; Give read and write access
(contract-call? .calendar-sync grant-calendar-access 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM true true)
```

### Getting User's Events

```clarity
(contract-call? .calendar-sync get-user-events 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

## Security Considerations

- All event modifications require proper authorization
- Time values are validated to ensure integrity
- Conflict detection prevents double-booking
- Public/private event settings control visibility

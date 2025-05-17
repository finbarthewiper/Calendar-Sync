;; Calendar Synchronization Smart Contract
;; This contract allows users to manage and synchronize calendar events on the Stacks blockchain

;; Define error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-TIME (err u102))
(define-constant ERR-INVALID-INPUT (err u103))

;; Data structures for calendar events
(define-map events
  { event-id: uint }
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
)

;; Map to track a user's events
(define-map user-event-count
  { user: principal }
  { count: uint }
)

;; Map to track shared events (who has access to what)
(define-map event-permissions
  { event-id: uint, user: principal }
  { 
    can-view: bool,
    can-edit: bool,
    can-delete: bool
  }
)

;; Counter to generate unique event IDs
(define-data-var next-event-id uint u1)

;; Function to get current event ID and increment for next use
(define-private (get-and-increment-event-id)
  (let ((current-id (var-get next-event-id)))
    (var-set next-event-id (+ current-id u1))
    current-id
  )
)

;; Function to get current block time
(define-private (get-current-time)
  (default-to u0 (get-block-info? time u0))
)

;; Validate that an event ID exists
(define-private (validate-event-id (event-id uint))
  (match (map-get? events { event-id: event-id })
    event-data true
    false
  )
)

;; Check if a user has permission for an event
(define-private (has-permission (event-id uint) (user principal) (permission-type (string-ascii 10)))
  (if (not (validate-event-id event-id))
    false
    (match (map-get? events { event-id: event-id })
      event (if (is-eq (get owner event) user)
              true  ;; Owner has all permissions
              (match (map-get? event-permissions { event-id: event-id, user: user })
                perms (if (is-eq permission-type "view")
                        (get can-view perms)
                        (if (is-eq permission-type "edit")
                          (get can-edit perms)
                          (if (is-eq permission-type "delete")
                            (get can-delete perms)
                            false
                          )
                        )
                      )
                false
              )
            )
      false
    )
  )
)

;; Function to validate string inputs
(define-private (validate-string (str (string-utf8 500)))
  (< u0 (len str))  ;; Basic validation to ensure non-empty string
)

;; Function to add a new event - with input validation
(define-public (create-event
  (title (string-utf8 100))
  (description (string-utf8 500))
  (start-time uint)
  (end-time uint)
  (location (string-utf8 100))
  (is-public bool)
)
  (let ((user tx-sender)
        (event-id (get-and-increment-event-id))
        (current-time (get-current-time)))
    
    ;; Input validations
    (asserts! (validate-string title) (err ERR-INVALID-INPUT))
    (asserts! (validate-string description) (err ERR-INVALID-INPUT))
    (asserts! (validate-string location) (err ERR-INVALID-INPUT))
    (asserts! (< start-time end-time) (err ERR-INVALID-TIME))
    
    ;; Create the event
    (map-set events
      { event-id: event-id }
      {
        owner: user,
        title: title,
        description: description,
        start-time: start-time,
        end-time: end-time,
        location: location,
        is-public: is-public,
        last-modified: current-time
      }
    )
    
    ;; Update user's event count
    (let ((user-count (default-to { count: u0 } (map-get? user-event-count { user: user }))))
      (map-set user-event-count
        { user: user }
        { count: (+ (get count user-count) u1) }))
    
    ;; Return the event ID
    (ok event-id)
  )
)

;; Function to read an event
(define-read-only (get-event (event-id uint))
  (match (map-get? events { event-id: event-id })
    event (ok event)
    (err ERR-EVENT-NOT-FOUND)
  )
)

;; Function to update an event - with proper validation
(define-public (update-event
  (event-id uint)
  (title (string-utf8 100))
  (description (string-utf8 500))
  (start-time uint)
  (end-time uint)
  (location (string-utf8 100))
  (is-public bool)
)
  (let ((user tx-sender)
        (current-time (get-current-time)))
    
    ;; Input validations
    (asserts! (validate-string title) (err ERR-INVALID-INPUT))
    (asserts! (validate-string description) (err ERR-INVALID-INPUT))
    (asserts! (validate-string location) (err ERR-INVALID-INPUT))
    (asserts! (< start-time end-time) (err ERR-INVALID-TIME))
    
    ;; Check if event exists
    (asserts! (validate-event-id event-id) (err ERR-EVENT-NOT-FOUND))
    
    ;; Verify permissions
    (asserts! (has-permission event-id user "edit") (err ERR-NOT-AUTHORIZED))
    
    ;; Get the event for owner information
    (match (map-get? events { event-id: event-id })
      event
        (begin
          ;; Update the event
          (map-set events
            { event-id: event-id }
            {
              owner: (get owner event),
              title: title,
              description: description,
              start-time: start-time,
              end-time: end-time,
              location: location,
              is-public: is-public,
              last-modified: current-time
            }
          )
          (ok true)
        )
      (err ERR-EVENT-NOT-FOUND)
    )
  )
)

;; Function to delete an event - with validation
(define-public (delete-event (event-id uint))
  (let ((user tx-sender))
    
    ;; Check if event exists
    (asserts! (validate-event-id event-id) (err ERR-EVENT-NOT-FOUND))
    
    ;; Verify permissions
    (asserts! (has-permission event-id user "delete") (err ERR-NOT-AUTHORIZED))
    
    ;; Get the event for owner information
    (match (map-get? events { event-id: event-id })
      event
        (begin
          ;; Remove from events map
          (map-delete events { event-id: event-id })
          
          ;; Update user's event count if the user is the owner
          (if (is-eq (get owner event) user)
            (let ((user-count (default-to { count: u0 } (map-get? user-event-count { user: user }))))
              (map-set user-event-count
                { user: user }
                { count: (- (get count user-count) u1) }))
            true)
          
          (ok true)
        )
      (err ERR-EVENT-NOT-FOUND)
    )
  )
)

;; Function to validate recipient
(define-private (validate-recipient (recipient principal))
  (not (is-eq recipient tx-sender))  ;; Basic validation to ensure recipient is not the sender
)

;; Function to share an event with another user - with validation
(define-public (share-event
  (event-id uint)
  (recipient principal)
  (can-view bool)
  (can-edit bool)
  (can-delete bool)
)
  (let ((user tx-sender))
    
    ;; Input validations
    (asserts! (validate-recipient recipient) (err ERR-INVALID-INPUT))
    
    ;; Check if event exists
    (asserts! (validate-event-id event-id) (err ERR-EVENT-NOT-FOUND))
    
    ;; Verify ownership
    (match (map-get? events { event-id: event-id })
      event
        (begin
          (asserts! (is-eq (get owner event) user) (err ERR-NOT-AUTHORIZED))
          
          ;; Set permissions - use match for safety when working with recipient
          (ok (map-set event-permissions
            { event-id: event-id, user: recipient }
            { 
              can-view: can-view,
              can-edit: can-edit,
              can-delete: can-delete
            }
          ))
        )
      (err ERR-EVENT-NOT-FOUND)
    )
  )
)

;; Function to get user's total event count
(define-read-only (get-user-event-count (user principal))
  (ok (default-to { count: u0 } (map-get? user-event-count { user: user })))
)

;; Function to get an event permission for a specific user
(define-read-only (get-event-permission (event-id uint) (user principal))
  (if (not (validate-event-id event-id))
    (err ERR-EVENT-NOT-FOUND)
    (ok (default-to
      { can-view: false, can-edit: false, can-delete: false }
      (map-get? event-permissions { event-id: event-id, user: user })))
  )
)
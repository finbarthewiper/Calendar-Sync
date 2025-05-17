;; Calendar Synchronization Smart Contract
;; This contract allows users to manage and synchronize calendar events on the Stacks blockchain

;; Define error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-TIME (err u102))

;; Data structures for calendar events - simplified
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

;; Check if a user has permission for an event
(define-private (has-permission (event-id uint) (user principal) (permission-type (string-ascii 10)))
  (let ((event-data (map-get? events { event-id: event-id })))
    (if (is-none event-data)
      false
      (let ((event (unwrap-panic event-data)))
        (if (is-eq (get owner event) user)
          true  ;; Owner has all permissions
          (let ((permission-data (map-get? event-permissions { event-id: event-id, user: user })))
            (if (is-none permission-data)
              false
              (let ((perms (unwrap-panic permission-data)))
                (if (is-eq permission-type "view")
                  (get can-view perms)
                  (if (is-eq permission-type "edit")
                    (get can-edit perms)
                    (if (is-eq permission-type "delete")
                      (get can-delete perms)
                      false
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  )
)

;; Function to add a new event - simplified version
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
    
    ;; Basic validations
    (if (>= start-time end-time)
      (err ERR-INVALID-TIME)
      
      ;; Create the event
      (begin
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
        (ok event-id))
    )
  )
)

;; Function to read an event
(define-read-only (get-event (event-id uint))
  (let ((event-data (map-get? events { event-id: event-id })))
    (if (is-none event-data)
      (err ERR-EVENT-NOT-FOUND)
      (ok (unwrap-panic event-data)))
  )
)

;; Function to update an event
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
        (current-time (get-current-time))
        (event-data (map-get? events { event-id: event-id })))
    
    ;; Check if event exists
    (if (is-none event-data)
      (err ERR-EVENT-NOT-FOUND)
      (begin
        ;; Verify permissions
        (if (not (has-permission event-id user "edit"))
          (err ERR-NOT-AUTHORIZED)
          (begin
            ;; Validate time
            (if (>= start-time end-time)
              (err ERR-INVALID-TIME)
              (begin
                ;; Update the event
                (map-set events
                  { event-id: event-id }
                  {
                    owner: (get owner (unwrap-panic event-data)),
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
            )
          )
        )
      )
    )
  )
)

;; Function to delete an event
(define-public (delete-event (event-id uint))
  (let ((user tx-sender)
        (event-data (map-get? events { event-id: event-id })))
    
    ;; Check if event exists
    (if (is-none event-data)
      (err ERR-EVENT-NOT-FOUND)
      (begin
        ;; Verify permissions
        (if (not (has-permission event-id user "delete"))
          (err ERR-NOT-AUTHORIZED)
          (begin
            ;; Remove from events map
            (map-delete events { event-id: event-id })
            
            ;; Update user's event count if the user is the owner
            (if (is-eq (get owner (unwrap-panic event-data)) user)
              (let ((user-count (default-to { count: u0 } (map-get? user-event-count { user: user }))))
                (map-set user-event-count
                  { user: user }
                  { count: (- (get count user-count) u1) }))
              true)
            
            (ok true)
          )
        )
      )
    )
  )
)

;; Function to share an event with another user
(define-public (share-event
  (event-id uint)
  (recipient principal)
  (can-view bool)
  (can-edit bool)
  (can-delete bool)
)
  (let ((user tx-sender)
        (event-data (map-get? events { event-id: event-id })))
    
    ;; Check if event exists
    (if (is-none event-data)
      (err ERR-EVENT-NOT-FOUND)
      (begin
        ;; Verify ownership
        (if (not (is-eq (get owner (unwrap-panic event-data)) user))
          (err ERR-NOT-AUTHORIZED)
          (begin
            ;; Set permissions
            (map-set event-permissions
              { event-id: event-id, user: recipient }
              { 
                can-view: can-view,
                can-edit: can-edit,
                can-delete: can-delete
              }
            )
            
            (ok true)
          )
        )
      )
    )
  )
)

;; Function to get user's total event count
(define-read-only (get-user-event-count (user principal))
  (ok (default-to { count: u0 } (map-get? user-event-count { user: user })))
)

;; Function to get an event permission for a specific user
(define-read-only (get-event-permission (event-id uint) (user principal))
  (let ((permission-data (map-get? event-permissions { event-id: event-id, user: user })))
    (if (is-none permission-data)
      (ok {
        can-view: false,
        can-edit: false,
        can-delete: false
      })
      (ok (unwrap-panic permission-data)))
  )
)
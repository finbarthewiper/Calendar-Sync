;; Calendar Synchronization Smart Contract
;; This contract allows users to manage and synchronize calendar events on the Stacks blockchain

;; Define error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-EVENT-NOT-FOUND (err u101))
(define-constant ERR-INVALID-TIME (err u102))
(define-constant ERR-EVENT-OVERLAP (err u103))
(define-constant ERR-INVALID-EVENT-ID (err u104))

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
(define-map user-events
  { user: principal }
  { event-list: (list 20 uint) }
)

;; Map for shared calendar access
(define-map calendar-access
  { calendar-owner: principal, accessor: principal }
  { can-read: bool, can-write: bool }
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

;; Helper function to check if user has access to an event
(define-private (has-event-access (event-id uint) (user principal))
  (let (
    (event (map-get? events { event-id: event-id }))
  )
    (if (is-none event)
      false
      (let (
        (event-data (unwrap-panic event))
        (owner (get owner event-data))
        (is-public (get is-public event-data))
        (access (map-get? calendar-access { calendar-owner: owner, accessor: user }))
      )
        (or
          (is-eq owner user)
          is-public
          (and
            (is-some access)
            (get can-read (unwrap-panic access))
          )
        )
      )
    )
  )
)

;; Function to check time conflicts for a user
(define-private (has-time-conflict (user principal) (start-time uint) (end-time uint) (exclude-id uint))
  (let (
    (user-event-data (map-get? user-events { user: user }))
  )
    (if (is-none user-event-data)
      false
      (let (
        (event-list (get event-list (unwrap-panic user-event-data)))
      )
        (fold check-overlap-fold event-list false)
      )
    )
  )
  
  (define-private (check-overlap-fold (event-id uint) (has-overlap bool))
    (if has-overlap
      true
      (let (
        (event (map-get? events { event-id: event-id }))
      )
        (if (or (is-none event) (is-eq event-id exclude-id))
          false
          (let (
            (event-data (unwrap-panic event))
            (event-start (get start-time event-data))
            (event-end (get end-time event-data))
          )
            (and
              (< event-start end-time)
              (> event-end start-time)
            )
          )
        )
      )
    )
  )
)

;; Function to add a new event
(define-public (create-event 
  (title (string-utf8 100)) 
  (description (string-utf8 500)) 
  (start-time uint) 
  (end-time uint) 
  (location (string-utf8 100))
  (is-public bool)
)
  (let (
    (user tx-sender)
    (current-time (get-block-info? time (get-burn-block-info? header-hash (get-burnchain-header-hash))))
    (event-id (get-and-increment-event-id))
  )
    ;; Validate inputs
    (asserts! (< start-time end-time) ERR-INVALID-TIME)
    (asserts! (is-some current-time) ERR-INVALID-TIME)
    (asserts! (>= start-time (unwrap-panic current-time)) ERR-INVALID-TIME)
    (asserts! (not (has-time-conflict user start-time end-time u0)) ERR-EVENT-OVERLAP)
    
    ;; Create event
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
        last-modified: (unwrap-panic current-time)
      }
    )
    
    ;; Add event to user's list
    (let (
      (user-event-data (map-get? user-events { user: user }))
    )
      (if (is-none user-event-data)
        (map-set user-events 
          { user: user }
          { event-list: (list event-id) }
        )
        (map-set user-events
          { user: user }
          { event-list: (append (get event-list (unwrap-panic user-event-data)) event-id) }
        )
      )
    )
    
    (ok event-id)
  )
)

;; Function to update an existing event
(define-public (update-event
  (event-id uint)
  (title (string-utf8 100)) 
  (description (string-utf8 500)) 
  (start-time uint) 
  (end-time uint) 
  (location (string-utf8 100))
  (is-public bool)
)
  (let (
    (user tx-sender)
    (current-time (get-block-info? time (get-burn-block-info? header-hash (get-burnchain-header-hash))))
    (event (map-get? events { event-id: event-id }))
  )
    ;; Validate inputs
    (asserts! (is-some event) ERR-EVENT-NOT-FOUND)
    (asserts! (< start-time end-time) ERR-INVALID-TIME)
    (asserts! (is-some current-time) ERR-INVALID-TIME)
    
    (let (
      (event-data (unwrap-panic event))
      (owner (get owner event-data))
      (access (map-get? calendar-access { calendar-owner: owner, accessor: user }))
    )
      ;; Check authorization
      (asserts! 
        (or 
          (is-eq owner user)
          (and 
            (is-some access)
            (get can-write (unwrap-panic access))
          )
        ) 
        ERR-NOT-AUTHORIZED
      )
      
      ;; Check for time conflicts (excluding this event)
      (asserts! (not (has-time-conflict user start-time end-time event-id)) ERR-EVENT-OVERLAP)
      
      ;; Update the event
      (map-set events 
        { event-id: event-id }
        {
          owner: owner,
          title: title,
          description: description,
          start-time: start-time,
          end-time: end-time,
          location: location,
          is-public: is-public,
          last-modified: (unwrap-panic current-time)
        }
      )
      
      (ok true)
    )
  )
)

;; Function to delete an event
(define-public (delete-event (event-id uint))
  (let (
    (user tx-sender)
    (event (map-get? events { event-id: event-id }))
  )
    ;; Validate inputs
    (asserts! (is-some event) ERR-EVENT-NOT-FOUND)
    
    (let (
      (event-data (unwrap-panic event))
      (owner (get owner event-data))
      (access (map-get? calendar-access { calendar-owner: owner, accessor: user }))
    )
      ;; Check authorization
      (asserts! 
        (or 
          (is-eq owner user)
          (and 
            (is-some access)
            (get can-write (unwrap-panic access))
          )
        ) 
        ERR-NOT-AUTHORIZED
      )
      
      ;; Remove from events map
      (map-delete events { event-id: event-id })
      
      ;; Remove from user's event list
      (let (
        (user-event-data (map-get? user-events { user: owner }))
      )
        (if (is-some user-event-data)
          (let (
            (event-list (get event-list (unwrap-panic user-event-data)))
            (filtered-list (filter remove-event-filter event-list))
          )
            (map-set user-events
              { user: owner }
              { event-list: filtered-list }
            )
          )
          true
        )
      )
      
      (ok true)
    )
  )
  
  (define-private (remove-event-filter (id uint))
    (not (is-eq id event-id))
  )
)

;; Function to read an event
(define-read-only (get-event (event-id uint))
  (let (
    (user tx-sender)
    (event (map-get? events { event-id: event-id }))
  )
    (asserts! (is-some event) ERR-EVENT-NOT-FOUND)
    (asserts! (has-event-access event-id user) ERR-NOT-AUTHORIZED)
    
    (ok (unwrap-panic event))
  )
)

;; Function to get all events for a user
(define-read-only (get-user-events (user principal))
  (let (
    (viewer tx-sender)
    (user-event-data (map-get? user-events { user: user }))
  )
    (if (is-none user-event-data)
      (ok (list))
      (let (
        (event-list (get event-list (unwrap-panic user-event-data)))
        (access (map-get? calendar-access { calendar-owner: user, accessor: viewer }))
        (can-access (or 
                      (is-eq user viewer)
                      (and 
                        (is-some access)
                        (get can-read (unwrap-panic access))
                      )
                    ))
      )
        (if can-access
          (ok event-list)
          (ok (filter get-public-events event-list))
        )
      )
    )
  )
  
  (define-private (get-public-events (event-id uint))
    (let (
      (event (map-get? events { event-id: event-id }))
    )
      (if (is-none event)
        false
        (get is-public (unwrap-panic event))
      )
    )
  )
)

;; Function to grant calendar access to another user
(define-public (grant-calendar-access (accessor principal) (can-read bool) (can-write bool))
  (let (
    (owner tx-sender)
  )
    (map-set calendar-access
      { calendar-owner: owner, accessor: accessor }
      { can-read: can-read, can-write: can-write }
    )
    
    (ok true)
  )
)

;; Function to revoke calendar access
(define-public (revoke-calendar-access (accessor principal))
  (let (
    (owner tx-sender)
  )
    (map-delete calendar-access
      { calendar-owner: owner, accessor: accessor }
    )
    
    (ok true)
  )
)

;; Function to check calendar access
(define-read-only (check-calendar-access (owner principal) (accessor principal))
  (let (
    (access (map-get? calendar-access { calendar-owner: owner, accessor: accessor }))
  )
    (if (is-none access)
      (ok { can-read: false, can-write: false })
      (ok (unwrap-panic access))
    )
  )
)
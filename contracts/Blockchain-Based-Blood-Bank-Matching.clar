(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_BLOOD_TYPE (err u101))
(define-constant ERR_INSUFFICIENT_INVENTORY (err u102))
(define-constant ERR_ALREADY_REGISTERED (err u103))
(define-constant ERR_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_MATCHED (err u105))

(define-constant ERR_INVALID_TIME_WINDOW (err u109))
(define-constant ERR_DONOR_NOT_REGISTERED (err u110))
(define-constant ERR_SCHEDULE_CONFLICT (err u111))

(define-data-var next-schedule-id uint u1)

(define-data-var next-donor-id uint u1)
(define-data-var next-recipient-id uint u1)
(define-data-var next-urgency-token-id uint u1)

(define-map blood-inventory
  { blood-type: (string-ascii 3) }
  { units: uint, last-updated: uint }
)

(define-map donors
  { donor-id: uint }
  { 
    principal: principal,
    blood-type: (string-ascii 3),
    available: bool,
    registered-block: uint
  }
)

(define-map recipients
  { recipient-id: uint }
  {
    principal: principal,
    blood-type: (string-ascii 3),
    urgency-level: uint,
    matched: bool,
    registered-block: uint
  }
)

(define-map urgency-tokens
  { token-id: uint }
  {
    recipient-id: uint,
    urgency-level: uint,
    issued-block: uint,
    active: bool
  }
)

(define-map matches
  { match-id: uint }
  {
    donor-id: uint,
    recipient-id: uint,
    blood-type: (string-ascii 3),
    matched-block: uint
  }
)

(define-data-var next-match-id uint u1)

(define-private (is-valid-blood-type (blood-type (string-ascii 3)))
  (or 
    (is-eq blood-type "A+")
    (is-eq blood-type "A-")
    (is-eq blood-type "B+")
    (is-eq blood-type "B-")
    (is-eq blood-type "AB+")
    (is-eq blood-type "AB-")
    (is-eq blood-type "O+")
    (is-eq blood-type "O-")
  )
)

(define-private (can-donate-to (donor-type (string-ascii 3)) (recipient-type (string-ascii 3)))
  (or
    (is-eq donor-type recipient-type)
    (is-eq donor-type "O-")
    (and (is-eq donor-type "O+") (not (or (is-eq recipient-type "A-") (is-eq recipient-type "B-") (is-eq recipient-type "AB-") (is-eq recipient-type "O-"))))
    (and (is-eq donor-type "A-") (or (is-eq recipient-type "A+") (is-eq recipient-type "AB+")))
    (and (is-eq donor-type "B-") (or (is-eq recipient-type "B+") (is-eq recipient-type "AB+")))
    (and (is-eq donor-type "A+") (or (is-eq recipient-type "AB+")))
    (and (is-eq donor-type "B+") (or (is-eq recipient-type "AB+")))
  )
)

(define-public (add-blood-inventory (blood-type (string-ascii 3)) (units uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-valid-blood-type blood-type) ERR_INVALID_BLOOD_TYPE)
    (let (
      (current-inventory (default-to {units: u0, last-updated: u0} (map-get? blood-inventory {blood-type: blood-type})))
    )
      (ok (map-set blood-inventory 
        {blood-type: blood-type}
        {units: (+ (get units current-inventory) units), last-updated: stacks-block-height}
      ))
    )
  )
)

(define-public (register-donor (blood-type (string-ascii 3)))
  (let (
    (donor-id (var-get next-donor-id))
  )
    (asserts! (is-valid-blood-type blood-type) ERR_INVALID_BLOOD_TYPE)
    (asserts! (is-none (map-get? donors {donor-id: donor-id})) ERR_ALREADY_REGISTERED)
    (map-set donors 
      {donor-id: donor-id}
      {
        principal: tx-sender,
        blood-type: blood-type,
        available: true,
        registered-block: stacks-block-height
      }
    )
    (var-set next-donor-id (+ donor-id u1))
    (ok donor-id)
  )
)

(define-public (register-recipient (blood-type (string-ascii 3)) (urgency-level uint))
  (let (
    (recipient-id (var-get next-recipient-id))
  )
    (asserts! (is-valid-blood-type blood-type) ERR_INVALID_BLOOD_TYPE)
    (asserts! (<= urgency-level u5) (err u106))
    (map-set recipients
      {recipient-id: recipient-id}
      {
        principal: tx-sender,
        blood-type: blood-type,
        urgency-level: urgency-level,
        matched: false,
        registered-block: stacks-block-height
      }
    )
    (var-set next-recipient-id (+ recipient-id u1))
    (ok recipient-id)
  )
)

(define-public (issue-urgency-token (recipient-id uint) (urgency-level uint))
  (let (
    (token-id (var-get next-urgency-token-id))
    (recipient (unwrap! (map-get? recipients {recipient-id: recipient-id}) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= urgency-level u5) (err u106))
    (map-set urgency-tokens
      {token-id: token-id}
      {
        recipient-id: recipient-id,
        urgency-level: urgency-level,
        issued-block: stacks-block-height,
        active: true
      }
    )
    (map-set recipients
      {recipient-id: recipient-id}
      (merge recipient {urgency-level: urgency-level})
    )
    (var-set next-urgency-token-id (+ token-id u1))
    (ok token-id)
  )
)

(define-public (match-donor-recipient (donor-id uint) (recipient-id uint))
  (let (
    (donor (unwrap! (map-get? donors {donor-id: donor-id}) ERR_NOT_FOUND))
    (recipient (unwrap! (map-get? recipients {recipient-id: recipient-id}) ERR_NOT_FOUND))
    (match-id (var-get next-match-id))
  )
    (asserts! (get available donor) (err u107))
    (asserts! (not (get matched recipient)) ERR_ALREADY_MATCHED)
    (asserts! (can-donate-to (get blood-type donor) (get blood-type recipient)) (err u108))
    
    (map-set donors
      {donor-id: donor-id}
      (merge donor {available: false})
    )
    (map-set recipients
      {recipient-id: recipient-id}
      (merge recipient {matched: true})
    )
    (map-set matches
      {match-id: match-id}
      {
        donor-id: donor-id,
        recipient-id: recipient-id,
        blood-type: (get blood-type recipient),
        matched-block: stacks-block-height
      }
    )
    (var-set next-match-id (+ match-id u1))
    (ok match-id)
  )
)

(define-read-only (get-blood-inventory (blood-type (string-ascii 3)))
  (map-get? blood-inventory {blood-type: blood-type})
)

(define-read-only (get-donor (donor-id uint))
  (map-get? donors {donor-id: donor-id})
)

(define-read-only (get-recipient (recipient-id uint))
  (map-get? recipients {recipient-id: recipient-id})
)

(define-read-only (get-urgency-token (token-id uint))
  (map-get? urgency-tokens {token-id: token-id})
)

(define-read-only (get-match (match-id uint))
  (map-get? matches {match-id: match-id})
)

(define-read-only (get-current-block)
  stacks-block-height
)


(define-map donor-schedules
  { schedule-id: uint }
  {
    donor-id: uint,
    start-block: uint,
    end-block: uint,
    active: bool,
    created-block: uint
  }
)

(define-map donor-to-schedules
  { donor-id: uint }
  { schedule-ids: (list 10 uint) }
)

(define-private (schedule-overlaps (start1 uint) (end1 uint) (start2 uint) (end2 uint))
  (not (or (< end1 start2) (< end2 start1)))
)

(define-private (has-schedule-conflict (donor-id uint) (new-start uint) (new-end uint))
  (let (
    (existing-schedules (default-to {schedule-ids: (list)} (map-get? donor-to-schedules {donor-id: donor-id})))
    (check-result (fold check-conflict-fold (get schedule-ids existing-schedules) {start: new-start, end: new-end, conflict: false}))
  )
    (get conflict check-result)
  )
)

(define-private (check-conflict-fold (schedule-id uint) (acc {start: uint, end: uint, conflict: bool}))
  (if (get conflict acc)
    acc
    (match (map-get? donor-schedules {schedule-id: schedule-id})
      schedule (if (and 
        (get active schedule)
        (schedule-overlaps (get start acc) (get end acc) (get start-block schedule) (get end-block schedule))
      )
        (merge acc {conflict: true})
        acc
      )
      acc
    )
  )
)

(define-public (set-donor-schedule (donor-id uint) (start-block uint) (end-block uint))
  (let (
    (schedule-id (var-get next-schedule-id))
    (donor-exists (is-some (map-get? donors {donor-id: donor-id})))
    (current-schedules (default-to {schedule-ids: (list)} (map-get? donor-to-schedules {donor-id: donor-id})))
  )
    (asserts! donor-exists ERR_DONOR_NOT_REGISTERED)
    (asserts! (< start-block end-block) ERR_INVALID_TIME_WINDOW)
    (asserts! (>= start-block stacks-block-height) ERR_INVALID_TIME_WINDOW)
    (asserts! (not (has-schedule-conflict donor-id start-block end-block)) ERR_SCHEDULE_CONFLICT)
    
    (map-set donor-schedules
      {schedule-id: schedule-id}
      {
        donor-id: donor-id,
        start-block: start-block,
        end-block: end-block,
        active: true,
        created-block: stacks-block-height
      }
    )
    
    (map-set donor-to-schedules
      {donor-id: donor-id}
      {schedule-ids: (unwrap! (as-max-len? (append (get schedule-ids current-schedules) schedule-id) u10) ERR_SCHEDULE_CONFLICT)}
    )
    
    (var-set next-schedule-id (+ schedule-id u1))
    (ok schedule-id)
  )
)

(define-public (cancel-schedule (schedule-id uint))
  (let (
    (schedule (unwrap! (map-get? donor-schedules {schedule-id: schedule-id}) ERR_NOT_FOUND))
    (donor (unwrap! (map-get? donors {donor-id: (get donor-id schedule)}) ERR_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get principal donor)) ERR_UNAUTHORIZED)
    (ok (map-set donor-schedules
      {schedule-id: schedule-id}
      (merge schedule {active: false})
    ))
  )
)

(define-read-only (is-donor-available-now (donor-id uint))
  (let (
    (schedules (default-to {schedule-ids: (list)} (map-get? donor-to-schedules {donor-id: donor-id})))
  )
    (> (len (filter check-current-availability (get schedule-ids schedules))) u0)
  )
)

(define-private (check-current-availability (schedule-id uint))
  (match (map-get? donor-schedules {schedule-id: schedule-id})
    schedule (and
      (get active schedule)
      (<= (get start-block schedule) stacks-block-height)
      (>= (get end-block schedule) stacks-block-height)
    )
    false
  )
)

(define-read-only (get-donor-schedule (schedule-id uint))
  (map-get? donor-schedules {schedule-id: schedule-id})
)

(define-read-only (get-donor-schedules (donor-id uint))
  (map-get? donor-to-schedules {donor-id: donor-id})
)
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_BLOOD_TYPE (err u101))
(define-constant ERR_INSUFFICIENT_INVENTORY (err u102))
(define-constant ERR_ALREADY_REGISTERED (err u103))
(define-constant ERR_NOT_FOUND (err u104))
(define-constant ERR_ALREADY_MATCHED (err u105))

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

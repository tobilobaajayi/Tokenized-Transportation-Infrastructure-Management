;; Condition Monitoring Contract
;; Tracks physical state of transportation infrastructure

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-asset-not-found (err u101))
(define-constant err-condition-not-found (err u102))
(define-constant err-unauthorized (err u103))

;; Data structures
(define-map asset-conditions
  { asset-id: uint }
  {
    condition-rating: uint,  ;; 1-10 scale (10 being excellent)
    inspection-date: uint,
    inspector: principal,
    notes: (string-utf8 500),
    last-updated: uint
  }
)

(define-map condition-history
  { asset-id: uint, timestamp: uint }
  {
    condition-rating: uint,
    inspector: principal,
    notes: (string-utf8 500)
  }
)

;; Public functions
(define-public (record-condition
                (asset-id uint)
                (condition-rating uint)
                (notes (string-utf8 500)))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (inspector tx-sender)
    )
    ;; Validate condition rating (1-10)
    (asserts! (and (>= condition-rating u1) (<= condition-rating u10)) (err u104))

    ;; Record current condition
    (map-set asset-conditions
      { asset-id: asset-id }
      {
        condition-rating: condition-rating,
        inspection-date: current-time,
        inspector: inspector,
        notes: notes,
        last-updated: current-time
      }
    )

    ;; Add to history
    (map-set condition-history
      { asset-id: asset-id, timestamp: current-time }
      {
        condition-rating: condition-rating,
        inspector: inspector,
        notes: notes
      }
    )

    (ok true)
  )
)

(define-read-only (get-current-condition (asset-id uint))
  (map-get? asset-conditions { asset-id: asset-id })
)

(define-read-only (get-condition-at-time (asset-id uint) (timestamp uint))
  (map-get? condition-history { asset-id: asset-id, timestamp: timestamp })
)

(define-read-only (is-condition-critical (asset-id uint))
  (match (map-get? asset-conditions { asset-id: asset-id })
    condition (< (get condition-rating condition) u4)  ;; Rating below 4 is critical
    false
  )
)

;; Maintenance Scheduling Contract
;; Manages repair planning for infrastructure assets

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-asset-not-found (err u101))
(define-constant err-schedule-not-found (err u102))
(define-constant err-unauthorized (err u103))

;; Maintenance status
(define-constant status-scheduled u1)
(define-constant status-in-progress u2)
(define-constant status-completed u3)
(define-constant status-cancelled u4)

;; Data structures
(define-map maintenance-schedules
  { schedule-id: uint }
  {
    asset-id: uint,
    description: (string-utf8 200),
    scheduled-date: uint,
    estimated-duration: uint,  ;; in hours
    status: uint,
    assigned-to: principal,
    created-by: principal,
    created-at: uint,
    last-updated: uint
  }
)

(define-map asset-schedules
  { asset-id: uint }
  { schedule-ids: (list 100 uint) }
)

;; Schedule counter
(define-data-var schedule-counter uint u0)

;; Public functions
(define-public (schedule-maintenance
                (asset-id uint)
                (description (string-utf8 200))
                (scheduled-date uint)
                (estimated-duration uint)
                (assigned-to principal))
  (let
    (
      (schedule-id (+ (var-get schedule-counter) u1))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (creator tx-sender)
    )
    ;; Increment schedule counter
    (var-set schedule-counter schedule-id)

    ;; Create maintenance schedule
    (map-set maintenance-schedules
      { schedule-id: schedule-id }
      {
        asset-id: asset-id,
        description: description,
        scheduled-date: scheduled-date,
        estimated-duration: estimated-duration,
        status: status-scheduled,
        assigned-to: assigned-to,
        created-by: creator,
        created-at: current-time,
        last-updated: current-time
      }
    )

    ;; Update asset schedules
    (match (map-get? asset-schedules { asset-id: asset-id })
      existing-entry (map-set asset-schedules
                      { asset-id: asset-id }
                      { schedule-ids: (unwrap-panic (as-max-len? (append (get schedule-ids existing-entry) schedule-id) u100)) })
      (map-set asset-schedules
        { asset-id: asset-id }
        { schedule-ids: (list schedule-id) })
    )

    (ok schedule-id)
  )
)

(define-public (update-maintenance-status (schedule-id uint) (new-status uint))
  (let
    (
      (schedule (unwrap! (map-get? maintenance-schedules { schedule-id: schedule-id }) err-schedule-not-found))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Check if sender is assigned to this maintenance or is the creator
    (asserts! (or
                (is-eq tx-sender (get assigned-to schedule))
                (is-eq tx-sender (get created-by schedule))
                (is-eq tx-sender contract-owner)
              )
              err-unauthorized)

    ;; Validate status
    (asserts! (or
                (is-eq new-status status-scheduled)
                (is-eq new-status status-in-progress)
                (is-eq new-status status-completed)
                (is-eq new-status status-cancelled)
              )
              (err u104))

    ;; Update status
    (map-set maintenance-schedules
      { schedule-id: schedule-id }
      (merge schedule {
        status: new-status,
        last-updated: current-time
      })
    )

    (ok true)
  )
)

(define-read-only (get-maintenance-schedule (schedule-id uint))
  (map-get? maintenance-schedules { schedule-id: schedule-id })
)

(define-read-only (get-asset-schedules-list (asset-id uint))
  (map-get? asset-schedules { asset-id: asset-id })
)

(define-read-only (get-upcoming-maintenance (days uint))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (future-time (+ current-time (* days u86400)))  ;; days * seconds in a day
    )
    ;; Note: In a real implementation, we would need to iterate through all schedules
    ;; and filter by date range, but Clarity doesn't support this directly.
    ;; This is a placeholder for the concept.
    (ok { current-time: current-time, future-time: future-time })
  )
)

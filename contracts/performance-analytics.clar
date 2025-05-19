;; Performance Analytics Contract
;; Monitors infrastructure reliability and performance metrics

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-asset-not-found (err u101))
(define-constant err-unauthorized (err u103))

;; Data structures
(define-map asset-performance
  { asset-id: uint }
  {
    uptime-percentage: uint,  ;; 0-100
    maintenance-count: uint,
    total-maintenance-cost: uint,
    last-failure-date: (optional uint),
    mean-time-between-failures: (optional uint),  ;; in days
    last-updated: uint
  }
)

(define-map performance-history
  { asset-id: uint, timestamp: uint }
  {
    uptime-percentage: uint,
    maintenance-count: uint,
    total-maintenance-cost: uint
  }
)

;; Public functions
(define-public (record-performance-metrics
                (asset-id uint)
                (uptime-percentage uint)
                (maintenance-count uint)
                (total-maintenance-cost uint)
                (last-failure-date (optional uint))
                (mean-time-between-failures (optional uint)))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Only contract owner or authorized users can update performance metrics
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)

    ;; Validate uptime percentage (0-100)
    (asserts! (<= uptime-percentage u100) (err u104))

    ;; Update performance metrics
    (map-set asset-performance
      { asset-id: asset-id }
      {
        uptime-percentage: uptime-percentage,
        maintenance-count: maintenance-count,
        total-maintenance-cost: total-maintenance-cost,
        last-failure-date: last-failure-date,
        mean-time-between-failures: mean-time-between-failures,
        last-updated: current-time
      }
    )

    ;; Add to history
    (map-set performance-history
      { asset-id: asset-id, timestamp: current-time }
      {
        uptime-percentage: uptime-percentage,
        maintenance-count: maintenance-count,
        total-maintenance-cost: total-maintenance-cost
      }
    )

    (ok true)
  )
)

(define-public (record-failure (asset-id uint))
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (performance (unwrap! (map-get? asset-performance { asset-id: asset-id }) err-asset-not-found))
      (last-failure (get last-failure-date performance))
      (new-mtbf (match last-failure
                  prev-failure (some (/ (- current-time prev-failure) u86400))  ;; Convert seconds to days
                  none))
    )
    ;; Update performance with new failure data
    (map-set asset-performance
      { asset-id: asset-id }
      (merge performance {
        last-failure-date: (some current-time),
        mean-time-between-failures: new-mtbf,
        last-updated: current-time
      })
    )

    (ok true)
  )
)

(define-read-only (get-asset-performance (asset-id uint))
  (map-get? asset-performance { asset-id: asset-id })
)

(define-read-only (get-performance-at-time (asset-id uint) (timestamp uint))
  (map-get? performance-history { asset-id: asset-id, timestamp: timestamp })
)

(define-read-only (get-critical-assets (uptime-threshold uint))
  ;; Note: In a real implementation, we would need to iterate through all assets
  ;; and filter by uptime below threshold, but Clarity doesn't support this directly.
  ;; This is a placeholder for the concept.
  (ok { uptime-threshold: uptime-threshold })
)

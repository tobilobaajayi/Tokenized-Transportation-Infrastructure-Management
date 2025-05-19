;; Asset Registration Contract
;; Records transportation infrastructure assets

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-asset-exists (err u101))
(define-constant err-asset-not-found (err u102))

;; Data structures
(define-map assets
  { asset-id: uint }
  {
    name: (string-utf8 100),
    asset-type: (string-utf8 50),
    location: (string-utf8 100),
    installation-date: uint,
    last-updated: uint,
    owner: principal
  }
)

(define-map asset-ids-by-owner
  { owner: principal }
  { ids: (list 100 uint) }
)

;; Asset counter
(define-data-var asset-counter uint u0)

;; Public functions
(define-public (register-asset
                (name (string-utf8 100))
                (asset-type (string-utf8 50))
                (location (string-utf8 100))
                (installation-date uint))
  (let
    (
      (asset-id (+ (var-get asset-counter) u1))
      (owner tx-sender)
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Increment asset counter
    (var-set asset-counter asset-id)

    ;; Add asset to assets map
    (map-set assets
      { asset-id: asset-id }
      {
        name: name,
        asset-type: asset-type,
        location: location,
        installation-date: installation-date,
        last-updated: current-time,
        owner: owner
      }
    )

    ;; Update owner's asset list
    (match (map-get? asset-ids-by-owner { owner: owner })
      existing-entry (map-set asset-ids-by-owner
                      { owner: owner }
                      { ids: (unwrap-panic (as-max-len? (append (get ids existing-entry) asset-id) u100)) })
      (map-set asset-ids-by-owner
        { owner: owner }
        { ids: (list asset-id) })
    )

    (ok asset-id)
  )
)

(define-public (update-asset
                (asset-id uint)
                (name (string-utf8 100))
                (asset-type (string-utf8 50))
                (location (string-utf8 100)))
  (let
    (
      (asset (unwrap! (map-get? assets { asset-id: asset-id }) err-asset-not-found))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    ;; Check if sender is owner
    (asserts! (is-eq tx-sender (get owner asset)) err-owner-only)

    ;; Update asset
    (map-set assets
      { asset-id: asset-id }
      (merge asset {
        name: name,
        asset-type: asset-type,
        location: location,
        last-updated: current-time
      })
    )

    (ok true)
  )
)

(define-read-only (get-asset (asset-id uint))
  (map-get? assets { asset-id: asset-id })
)

(define-read-only (get-assets-by-owner (owner principal))
  (map-get? asset-ids-by-owner { owner: owner })
)

(define-read-only (get-asset-count)
  (var-get asset-counter)
)

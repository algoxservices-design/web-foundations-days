# TicketHub: High-Demand Concert and Event Ticketing Design

## 1. Requirements

TicketHub lets customers discover events, choose seats, reserve them temporarily, pay, and retrieve their tickets. The design must handle ordinary daily traffic and a sudden rush for a popular concert without selling any seat twice.

### Functional requirements
1. Visitors can browse, search, and filter published events by date, venue, category, and price.
2. Visitors can view event details, seat maps, prices, and current seat availability.
3. Authenticated customers can place a time-limited hold on one or more available seats.
4. Customers can pay for a valid hold and receive a confirmed order and tickets.
5. Customers can view their own orders and tickets.
6. The system expires unpaid holds and makes those seats available again.
7. Administrators can create events, configure seats and prices, publish events, and review sales.

### Non-functional requirements
- **Performance:** Event browsing should target a response time below 300 ms at the 95th percentile under normal load. During a sale, the system should use a waiting room and return clear status rather than overload indefinitely.
- **Correctness:** A seat must be allocated to at most one successful order. Seat ownership is enforced in the primary database, not by a browser or cache.
- **Fairness:** During a major sale, a server-managed waiting room admits customers using a consistent queue policy. Queue position must not improve merely because someone refreshes repeatedly. Hold duration and per-customer ticket limits are communicated clearly.
- **Availability and resilience:** Browsing should remain available where possible if checkout is under pressure. Failed or uncertain payment processing must not cause a seat to be sold twice.
- **Security and privacy:** Authentication is required for holds, checkout, and ticket access. Users may access only their own tickets and orders. Apply rate limits, validate input, protect payment credentials, and never store raw payment-card details.
- **Scalability:** Stateless application servers can scale horizontally; static assets and event information can be cached.
- **Observability:** Monitor latency, error rates, queue depth, database lock waits, active holds, and payment failures.

## 2. Traffic estimates

The following calculations use the supplied facts. Estimates are planning figures; actual capacity should be confirmed with load testing.

### Normal day
- Registered users: **2,000,000**.
- Daily visitors: **50,000**.
- Pages per visitor: **10**.
- Page views per day: 50,000 × 10 = **500,000 page views/day**.
- If spread across 24 hours, the average is 500,000 / 86,400 ≈ **5.8 page views/second**.
- For a more realistic active period of 10 hours, the average is 500,000 / 36,000 ≈ **13.9 page views/second**.
- If each page view causes an average of 4 API requests, this is about **55.6 API requests/second** over 10 active hours.
- Tickets sold: **5,000 per normal day**. If sales were evenly spread over 10 active hours, that is about 0.14 ticket sales/second on average. Actual sales will be uneven.

### Popular-concert sale
- People trying to buy tickets: **200,000 within 10 minutes**.
- Seats available: **20,000**.
- Average arrival rate: 200,000 / 600 seconds ≈ **333 people/second**.
- If each person makes 6 requests while browsing, checking seats, and attempting checkout, the system could receive around 1,200,000 requests in 10 minutes, or **2,000 requests/second on average**.
- There are **10 people competing for each seat** (200,000 / 20,000). At most 20,000 can buy seats for this concert, so the design must handle many legitimate “seat no longer available” responses.
- Arrival bursts may be much higher than the 10-minute average. TicketHub should load-test at several times the estimated average and use a virtual waiting room to control the rate reaching checkout.

### Comparison

| Measure | Normal day | Popular-concert sale |
|---|---:|---:|
| Visitors / attempted buyers | 50,000 daily visitors | 200,000 attempted buyers in 10 minutes |
| Page views / requests | 500,000 page views/day; ~56 API req/s during 10 active hours under the 4-requests-per-page assumption | ~2,000 API req/s under the 6-requests-per-person assumption |
| Ticket inventory | 5,000 tickets sold per day across events | 20,000 seats for one concert |
| Main challenge | Steady browsing and ordinary checkout | Sudden burst, queue fairness, database contention, and unavailable seats |

The popular-sale request rate is roughly 36 times the estimated normal active-period API rate (2,000 / 55.6 ≈ 36). The system must separate cacheable browsing from inventory-changing operations. The waiting room, rate limits, cache, and horizontal scaling handle demand; transactions and constraints protect seat correctness.

## 3. API design

All endpoints use HTTPS and JSON. Authenticated endpoints require a valid session or access token. Requests that create holds or orders accept an `Idempotency-Key` so network retries do not create duplicate operations.

| Method and endpoint | Purpose | Typical success response |
|---|---|---|
| `GET /api/v1/events?date=&category=&cursor=` | Browse and filter events with pagination | `200 OK` with event list and next cursor |
| `GET /api/v1/events/{event_id}` | Get event details, venue, date, and ticket rules | `200 OK` |
| `GET /api/v1/events/{event_id}/seats` | Get seat map, prices, and current availability | `200 OK` |
| `POST /api/v1/holds` | Temporarily hold available seats for the signed-in customer | `201 Created` with hold ID and expiry |
| `GET /api/v1/holds/{hold_id}` | Check hold status and expiration | `200 OK` |
| `DELETE /api/v1/holds/{hold_id}` | Release a hold owned by the customer | `204 No Content` |
| `POST /api/v1/orders` | Create an order for a valid hold and initiate payment | `201 Created` with order ID and payment-session details |
| `POST /api/v1/payment-webhooks/{provider}` | Receive and verify payment provider updates | `200 OK` after idempotent processing |
| `GET /api/v1/me/tickets` | List tickets belonging to the signed-in customer | `200 OK` |
| `GET /api/v1/me/tickets/{ticket_id}` | View one ticket owned by the customer | `200 OK` |

### Example: hold seats

Request:
```json
{
  "event_id": "evt_501",
  "seat_ids": ["A-12", "A-13"]
}
```

Successful response (`201 Created`):
```json
{
  "hold_id": "hold_8f21",
  "status": "active",
  "expires_at": "2030-06-12T14:05:00Z",
  "currency": "KES",
  "total_amount_minor": 600000
}
```

If any requested seat is unavailable, the server returns `409 Conflict` and does not partially hold the requested seats. The client must not assume a seat is secured until it receives a successful hold response.

### Example error body
```json
{
  "error": {
    "code": "SEAT_UNAVAILABLE",
    "message": "One or more selected seats are no longer available.",
    "request_id": "req_c71a"
  }
}
```

Use `400` for malformed input, `401` for unauthenticated requests, `403` for forbidden actions, `404` for missing resources, `409` for seat or hold conflicts, `429` for rate limiting, and `500` for unexpected server errors. Never return a customer's private ticket details to another customer.

## 4. Data model

A relational database such as PostgreSQL is suitable because ticket sales require transactions, foreign keys, and uniqueness constraints. Amounts are stored as integer minor units rather than floating-point numbers.

### Tables and relationships

- **users:** One user can create many holds and orders.
- **events:** One event has many seats and orders.
- **seats:** Each seat belongs to one event; `(event_id, seat_label)` is unique so a venue seat is not duplicated for the same event.
- **holds:** A temporary reservation made by a user for an event. It has an expiry time and a state.
- **hold_seats:** Join table linking a hold to its seats.
- **orders:** A user's purchase for an event; an order can contain multiple seats.
- **order_seats:** Join table linking orders to seats. A unique constraint on `seat_id` prevents the same seat being allocated to two successful orders.
- **tickets:** Issued after successful payment, one per sold seat.

Simplified PostgreSQL schema:

```sql
CREATE TABLE users (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE events (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    venue_name TEXT NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('draft', 'published', 'cancelled', 'completed'))
);

CREATE TABLE seats (
    id BIGSERIAL PRIMARY KEY,
    event_id BIGINT NOT NULL REFERENCES events(id),
    seat_label TEXT NOT NULL,
    section TEXT NOT NULL,
    price_minor BIGINT NOT NULL CHECK (price_minor >= 0),
    status TEXT NOT NULL DEFAULT 'available'
        CHECK (status IN ('available', 'held', 'sold')),
    UNIQUE (event_id, seat_label)
);

CREATE TABLE holds (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    event_id BIGINT NOT NULL REFERENCES events(id),
    status TEXT NOT NULL CHECK (status IN ('active', 'converted', 'released', 'expired')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE hold_seats (
    hold_id BIGINT NOT NULL REFERENCES holds(id),
    seat_id BIGINT NOT NULL REFERENCES seats(id),
    PRIMARY KEY (hold_id, seat_id)
);

CREATE TABLE orders (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    event_id BIGINT NOT NULL REFERENCES events(id),
    status TEXT NOT NULL
        CHECK (status IN ('pending_payment', 'paid', 'failed', 'cancelled', 'expired')),
    total_minor BIGINT NOT NULL CHECK (total_minor >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'KES',
    idempotency_key TEXT NOT NULL,
    payment_reference TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, idempotency_key)
);

CREATE TABLE order_seats (
    order_id BIGINT NOT NULL REFERENCES orders(id),
    seat_id BIGINT NOT NULL REFERENCES seats(id),
    price_minor BIGINT NOT NULL CHECK (price_minor >= 0),
    PRIMARY KEY (order_id, seat_id),
    UNIQUE (seat_id)
);

CREATE TABLE tickets (
    id BIGSERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id),
    seat_id BIGINT NOT NULL UNIQUE REFERENCES seats(id),
    ticket_code_hash TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL CHECK (status IN ('valid', 'used', 'void')),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX events_status_start_idx ON events (status, starts_at);
CREATE INDEX seats_event_status_idx ON seats (event_id, status);
CREATE INDEX holds_expiry_idx ON holds (expires_at) WHERE status = 'active';
CREATE INDEX orders_user_created_idx ON orders (user_id, created_at DESC);
```

The `UNIQUE (seat_id)` constraint in `order_seats` is a final guard against assigning one seat to multiple orders. Application logic must also ensure only a currently valid hold can be converted to a paid order. Production implementations should keep seat inventory state authoritative in the `seats` row and handle hold expiry under the same locking rules; historical hold rows should not permanently block seats.

## 5. Preventing double-booking

A seat map is only a snapshot. Two customers can view the same seat as available at almost the same time, so checking availability in the browser is not sufficient. The primary database must decide which request wins.

### Holding seats safely
1. Begin a database transaction.
2. Select the requested seat rows from the primary database in sorted ID order using `SELECT ... FOR UPDATE`. This locks the rows while the transaction is running.
3. Verify every seat belongs to the event and is available, or is associated with a hold that has safely expired.
4. If any requested seat cannot be held, roll back the entire transaction and return `409 Conflict`.
5. Otherwise, conditionally update all requested seats to `held`, record the hold owner and expiry, and commit.
6. Verify the number of rows updated equals the number requested. If not, roll back.

Conceptual SQL:
```sql
BEGIN;

SELECT id, status
FROM seats
WHERE event_id = :event_id
  AND id = ANY(:seat_ids)
ORDER BY id
FOR UPDATE;

-- Application verifies that every requested seat is available.
-- If any seat is unavailable, ROLLBACK and return 409.

UPDATE seats
SET status = 'held'
WHERE event_id = :event_id
  AND id = ANY(:seat_ids)
  AND status = 'available';

-- Verify affected row count matches the requested seat count.
-- If not, ROLLBACK.

COMMIT;
```

The actual production schema should record `hold_id` and `hold_expires_at` in the inventory row or use a transactionally consistent inventory table. An expiry worker must lock the same rows and conditionally return expired holds to `available`; correctness must not depend on the worker running exactly on time.

### Completing payment safely
- Create an order from a valid hold and use an idempotency key to prevent duplicate orders on client retries.
- Verify payment with a signed provider webhook or a server-to-server provider lookup; do not trust a browser success message.
- In a transaction, lock the order, hold, and relevant seat rows; confirm the hold is still valid and the provider event has not already been processed.
- Mark the order paid, mark seats sold, and create tickets atomically.
- Enforce unique seat-to-order and payment-reference constraints. Duplicate payment callbacks must be harmless.
- If payment succeeds after a hold has expired and the seats cannot be guaranteed, send the transaction through a recovery/refund workflow instead of allocating a seat twice.

**Why this works:** row locks serialize competing seat claims; conditional updates ensure only available seats can change to held; transactions make multi-seat holds all-or-nothing; unique constraints provide a final database-level safeguard; and idempotency prevents retries from creating duplicate purchases.

## 6. Architecture and how it handles the big sale

```text
                          Customers
                              |
                              v
                       DNS + CDN + WAF
                 (static assets, edge protection)
                              |
                              v
                   Virtual waiting room
                  (fair admission + rate limits)
                              |
                              v
                         Load balancer
                              |
                +-------------+-------------+
                |             |             |
                v             v             v
            API server 1  API server 2  API server N
                |             |             |
                +-------------+-------------+
                              |
                +-------------+----------------+
                |                              |
                v                              v
        Read cache / read replica       Primary SQL database
        (events and safe reads)         (holds, seats, orders)
                                               |
                                      +--------+--------+
                                      |                 |
                                      v                 v
                                Durable queue      Payment provider
                                      |
                                      v
                               Background workers
                         (hold expiry, notifications,
                          ticket delivery, retries)

                 Monitoring, logs, metrics and alerts
                         cover all components
```

### Component responsibilities
- **DNS/CDN/WAF:** Routes traffic, serves static files near customers, and filters common malicious or abusive traffic.
- **Virtual waiting room:** Smooths the 200,000-person arrival burst, applies a consistent queue policy, and limits how many users reach checkout simultaneously.
- **Load balancer:** Distributes admitted requests across healthy application servers.
- **Multiple stateless API servers:** Serve event browsing and checkout. Additional instances can be added during a sale without moving session state between servers.
- **Read cache:** Stores event descriptions, venue details, and other read-heavy information. Cached seat availability is informational only and never grants ownership.
- **Read replica:** Serves suitable read-only queries and reporting. Seat holds and payment finalization must use the primary database, not a potentially stale replica.
- **Primary relational database:** Is the source of truth for seat state, holds, orders, and ticket issuance. It uses transactions, constraints, connection pooling, backups, and a tested failover plan.
- **Durable queue and workers:** Handle emails, SMS, hold-expiry tasks, and other retryable work outside the checkout request. Workers must be idempotent.
- **Payment provider:** Processes payment. TicketHub verifies callbacks and reconciles uncertain payment states.
- **Monitoring and alerting:** Tracks latency, error rates, queue depth, database locks, payment failures, and resource saturation.

### Big-sale operating plan
1. Cache static assets and event information so the database is not queried for every page view.
2. Admit users gradually through the waiting room rather than sending all 200,000 people to checkout at once.
3. Horizontally scale stateless API servers and rate-limit abusive clients.
4. Protect the primary database with a bounded connection pool, indexed queries, and short transactions.
5. Send nonessential work such as notifications to a durable queue.
6. Load-test the complete journey—including seat contention, payment retries, and expired holds—before the sale.
7. Set alerts and prepare an operational runbook for reducing admission rate, pausing sales safely, and recovering from payment-provider or database problems.
8. Maintain backups and rehearse database failover. A read replica alone is not a complete disaster-recovery plan.

## 7. Trade-offs

### Trade-off 1: Correctness versus throughput
Row locks and transactions prevent double-booking, but requests for the same popular seats can block one another and lower checkout throughput. TicketHub prioritizes correctness because selling the same seat twice is worse than asking a customer to retry. A waiting room, short transactions, and consistent lock order reduce contention.

### Trade-off 2: Fast browsing versus fresh availability
Caching seat availability reduces load and makes seat maps faster, but a cached map can be stale. TicketHub can cache event details and use cached seat status as a visual hint, but every hold must be validated atomically against the primary database.

### Trade-off 3: Immediate access versus fair admission
A waiting room introduces delay, but uncontrolled simultaneous traffic can overload the service and unfairly reward users who refresh or automate requests. A clearly explained, consistently applied queue is more predictable and protects the purchase process.

### Trade-off 4: Synchronous checkout versus asynchronous work
The core order and inventory changes need transactionally consistent handling. Sending emails and SMS synchronously would slow checkout, so these tasks are queued. This improves response time but adds worker operations, retries, and dead-letter handling.

## Assumptions and validation

The 4 API requests per page and 6 requests per attempted buyer are planning assumptions because the supplied facts specify page views and attempted buyers, not exact API calls. Traffic is bursty, so averages are not sufficient for capacity planning. Validate assumptions using load tests and real metrics before launch.

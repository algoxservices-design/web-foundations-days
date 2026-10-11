# SnapShare Photo-Sharing App: Scaling Plan

## 1. Assumptions and Workload Estimates

SnapShare is a photo-sharing application where users upload photos and view a feed containing photos from people they follow.

### Given facts

- Registered users: 10,000,000
- Daily active users: 10% of registered users
- Uploads per active user: 1 photo per day
- Feed views per active user: 50 pages per day
- Average original photo size: 2 MB
- Average thumbnail size: 50 KB
- Seconds per day: 86,400
- Days per year: 365
- Peak traffic factor: 5 times the average rate

### Assumptions

1. Ten percent of registered users are active each day, and each active user uploads exactly one photo daily.
2. Each active user views 50 feed pages daily, and each feed-page request is counted as one feed view.
3. Each uploaded photo produces one thumbnail.
4. All uploaded photos and thumbnails are retained for a full year, with no deletions or compression beyond the stated thumbnail size.
5. The estimates represent average traffic across 24 hours. Peak feed traffic is five times the average rate.
6. Storage calculations use decimal units: 1 GB = 1,000 MB and 1 TB = 1,000 GB.
7. The estimates exclude database records, indexes, backups, replication overhead, logs, and other application data.

### A. Calculate daily active users

Daily active users (DAU) are 10% of the 10 million registered users.

DAU = 10,000,000 × 0.10

**Daily active users = 1,000,000**

Therefore, SnapShare has approximately one million active users per day.

### B. Calculate photo uploads per second

Each daily active user uploads one photo per day.

Daily uploads = 1,000,000 × 1

Daily uploads = 1,000,000 photos

Average uploads per second:

1,000,000 ÷ 86,400 = 11.57

**Average upload rate ≈ 11.6 photos per second.**

This is an average, so actual uploads may be much higher during busy periods.

### C. Calculate feed views per second

Each active user views 50 feed pages per day.

Daily feed views = 1,000,000 × 50

Daily feed views = 50,000,000

Average feed views per second:

50,000,000 ÷ 86,400 = 578.70

**Average feed-view rate ≈ 579 requests per second.**

Peak feed views use the required factor of five:

Peak feed views = 578.70 × 5

Peak feed views ≈ 2,893.52

**Estimated peak feed-view rate ≈ 2,894 requests per second.**

This is the estimated feed-page request rate, not the number of individual photos or image bytes delivered. Loading images may generate additional CDN and storage requests.

### D. Calculate photo storage per year

Each original photo is 2 MB, and each thumbnail is 50 KB.

Convert the thumbnail size to megabytes:

50 KB = 0.05 MB

Total storage per uploaded photo:

2 MB + 0.05 MB = 2.05 MB

Daily storage required:

1,000,000 × 2.05 MB = 2,050,000 MB

Convert to gigabytes:

2,050,000 ÷ 1,000 = 2,050 GB

**Daily storage growth = 2.05 TB.**

Annual storage required:

2,050,000 MB × 365 = 748,250,000 MB

Convert to terabytes:

748,250,000 ÷ 1,000,000 = 748.25 TB

**Annual storage growth ≈ 748.25 TB, including original photos and thumbnails.**

Original photos alone require:

1,000,000 × 2 MB × 365 = 730 TB per year.

Thumbnails require:

1,000,000 × 0.05 MB × 365 = 18.25 TB per year.

Total:

730 TB + 18.25 TB = 748.25 TB per year.

This is the storage needed for one year of newly uploaded photos and thumbnails. It excludes backups, replicas, metadata, and storage overhead. If the service keeps every year's uploads, the total storage requirement will continue to grow.

### Summary of estimates

| Metric | Estimated value |
|---|---:|
| Registered users | 10,000,000 |
| Daily active users | 1,000,000 |
| Daily photo uploads | 1,000,000 |
| Average uploads per second | 11.6 |
| Daily feed views | 50,000,000 |
| Average feed views per second | 579 |
| Peak feed views per second | 2,894 |
| Storage growth per day | 2.05 TB |
| Storage growth per year | 748.25 TB |

## 2. Is SnapShare Read-Heavy or Write-Heavy?

SnapShare is a **read-heavy system** because users view approximately 50 million feed pages daily but upload only one million photos daily.

The ratio of feed views to uploads is:

50,000,000 ÷ 1,000,000 = 50:1

Therefore, the application receives approximately 50 feed-page views for every photo upload.

The design should prioritize fast feed delivery and efficient handling of read requests. A cache can serve frequently requested feed data, a CDN can deliver images from locations close to users, and database read replicas can handle read queries without sending all traffic to the primary database.

Photo uploads must still be reliable. The system should write photo metadata to the primary database and process thumbnail creation asynchronously through a queue and worker.

The average feed-view rate is approximately 579 requests per second, rising to approximately 2,894 requests per second at the assumed peak. The architecture should be tested under peak load and have enough capacity to scale horizontally.

## 3. Why Photos Should Not Be Stored Inside the Database

Original photos and thumbnails should be stored in object storage rather than as large binary files inside the relational database.

Photos are large files, and storing them directly in database tables can increase database storage costs, complicate backups, and make database operations more expensive. It also mixes large media files with the structured records needed for users, relationships, captions, and photo metadata.

Object storage is designed to store large files reliably and scale to very large capacities. The database should store metadata such as the photo ID, owner ID, caption, object-storage key, upload timestamp, and thumbnail key.

A CDN can then deliver frequently accessed photos and thumbnails from cached copies instead of repeatedly retrieving them from the origin storage.

## 4. SnapShare Architecture Diagram

The following diagram shows the main components and how requests and data move through the system.

```text
                         ┌────────────────────┐
                         │   Users / Clients  │
                         │ Browser and Mobile │
                         └─────────┬──────────┘
                                   │
                         ┌─────────▼──────────┐
                         │        DNS         │
                         │ Resolves app domain│
                         └─────────┬──────────┘
                                   │
                     ┌─────────────┴─────────────┐
                     │                           │
          Static files and images           API requests
                     │                           │
              ┌──────▼───────┐          ┌────────▼────────┐
              │ CDN / Edge   │          │ Load Balancer   │
              │ Cache images │          │ Distributes API │
              └──────┬───────┘          └────────┬────────┘
                     │                           │
                     │                   ┌───────┴────────┐
                     │                   │                │
                     │             ┌─────▼─────┐    ┌─────▼─────┐
                     │             │ App Server│    │ App Server│
                     │             │     1     │    │     2     │
                     │             └─────┬─────┘    └─────┬─────┘
                     │                   │                │
                     │                   └───────┬────────┘
                     │                           │
                     │                   ┌───────▼────────┐
                     │                   │ Cache (Redis)  │
                     │                   │ Feed data and  │
                     │                   │ hot metadata   │
                     │                   └───────┬────────┘
                     │                           │ Cache miss
                     │                           │
                     │                   ┌───────▼────────┐
                     │                   │ Read Replica   │
                     │                   │ Feed queries   │
                     │                   └───────▲────────┘
                     │                           │ Replication
                     │                   ┌───────┴────────┐
                     │                   │ Primary DB     │
                     │                   │ Metadata/writes│
                     │                   └────────────────┘
                     │
                     │
          ┌──────────▼───────────┐
          │ Object Storage       │
          │ Original photos and  │
          │ generated thumbnails │
          └──────────▲───────────┘
                     │
              ┌──────┴───────────┐
              │ Upload service   │
              │ or app server    │
              └──────┬───────────┘
                     │ Upload metadata / job
                     ▼
              ┌──────────────┐
              │ Message Queue│
              │ Thumbnail job│
              └──────┬───────┘
                     │
                     ▼
              ┌──────────────┐
              │ Thumbnail    │
              │ Worker        │
              └──────┬───────┘
                     │ Reads original,
                     │ creates thumbnail
                     ▼
              ┌──────────────────┐
              │ Object Storage   │
              │ Saves thumbnail  │
              └──────────────────┘
```

The CDN serves cached copies of images. On a cache miss, the image is retrieved from object storage and may be cached for later requests.

The primary database handles metadata writes, while the read replica handles suitable read queries. The cache reduces repeated database queries, and the queue allows thumbnail generation to happen outside the user's upload request.

## 5. What Each Component Does

1. **Users/clients:** Users upload photos and request feeds through a browser or mobile application.
2. **DNS:** DNS translates the application's domain name into the IP address of the appropriate service.
3. **CDN:** The CDN caches and delivers images from nearby edge locations, reducing latency and traffic reaching the origin storage.
4. **Load balancer:** The load balancer distributes API requests across healthy application servers so that one server does not handle all the traffic.
5. **Application servers:** Application servers validate requests, authenticate users, apply business rules, and coordinate database, cache, storage, and queue operations.
6. **Redis cache:** Redis stores frequently accessed feed data and metadata so repeated requests can be answered quickly without querying the database every time.
7. **Primary database:** The primary database stores structured information such as users, followers, photo records, captions, and object-storage keys, and accepts writes.
8. **Read replica:** The read replica handles suitable read queries, reducing the primary database's read workload while replication copies committed changes from the primary.
9. **Object storage:** Object storage holds original photos and thumbnails durably without filling the database with large binary files.
10. **Message queue:** The queue stores thumbnail-generation jobs so they can be processed asynchronously, even when uploads arrive faster than workers can process them.
11. **Thumbnail worker:** The worker consumes queued jobs, retrieves original photos, creates smaller thumbnails, stores them in object storage, and updates the relevant metadata.
12. **Rate limiting and timeouts:** Rate limiting restricts excessive requests, while timeouts prevent slow operations from holding resources indefinitely.
13. **Monitoring and health checks:** Monitoring identifies errors, latency, queue backlogs, and resource pressure, while health checks help the load balancer avoid unhealthy servers.

## 6. Step-by-Step Photo Upload Flow

1. **User starts an upload:** The user selects a photo in the SnapShare mobile app or website and submits it with a caption or other metadata.

2. **Request reaches the application:** DNS directs the client to the service, and the load balancer routes the API request to a healthy application server.

3. **Authenticate and validate:** The application server verifies the user's identity, checks permissions and file type, enforces file-size limits, and applies rate limits to reduce abuse.

4. **Upload the original photo:** The application obtains an upload destination and stores the original image in object storage. For large files, the client may upload directly to object storage using a short-lived signed upload URL.

5. **Save photo metadata:** The application writes a photo record to the primary database. The record includes the owner, caption, storage key, upload time, and processing status.

6. **Queue a thumbnail job:** After the original photo is safely stored, the application publishes a thumbnail-generation job to the message queue. The job contains the photo ID and the object-storage key.

7. **Acknowledge the upload:** The application responds to the client that the photo has been uploaded and accepted for processing. The thumbnail may still be pending.

8. **Worker processes the job:** A thumbnail worker retrieves the job, downloads or reads the original photo, and generates a smaller 50 KB thumbnail or an appropriately sized image variant.

9. **Store the thumbnail:** The worker saves the thumbnail in object storage and updates the photo record with its thumbnail key and processing status.

10. **Make the photo available in feeds:** The feed service includes the photo when appropriate for the owner's followers. Cache entries may be updated or invalidated so users do not continue seeing stale feed data.

11. **Deliver images efficiently:** When users scroll their feeds, the CDN serves cached photo files where possible. If a requested image is not cached, it retrieves the file from object storage and can cache it for future requests.

12. **Handle failures:** If thumbnail generation fails, the queue retries the job with back-off. After repeated failures, the job can be moved to a dead-letter queue for investigation. The original photo remains available, and the application can show a placeholder until the thumbnail is ready.

## 7. Scaling Protection and Reliability

SnapShare should include several safeguards to prevent overload and improve reliability.

- **Rate limiting:** Limit uploads and API requests per user or IP address to reduce abuse and prevent one client from consuming too many resources. Return HTTP 429 Too Many Requests when limits are exceeded.
- **Timeouts:** Set timeouts for database, object-storage, and external-service operations so requests do not wait indefinitely.
- **Retries with exponential back-off:** Retry temporary failures after progressively longer delays, such as one, two, and four seconds, while limiting the total number of attempts.
- **Graceful degradation:** If thumbnail generation is delayed, display the original photo or a placeholder rather than making the entire feed unavailable.
- **Horizontal scaling:** Add more stateless application servers and thumbnail workers when CPU use, request latency, or queue backlog increases.
- **Monitoring and alerts:** Track feed latency, upload failures, cache hit rate, database load, storage errors, and queue depth so capacity issues can be addressed early.

## 8. Trade-Offs

### Trade-off 1: CDN caching versus immediate freshness

A CDN improves photo delivery speed and reduces origin-storage traffic because popular images can be served from nearby edge locations. However, cached content may not reflect changes immediately. SnapShare can use versioned image URLs and suitable cache-control settings to keep image delivery fast while ensuring that updated or removed content is handled correctly.

### Trade-off 2: Read replicas versus consistency

Read replicas distribute feed-query traffic and reduce the workload on the primary database. However, replication may lag, meaning a newly uploaded photo or recently changed profile may not immediately appear in every read. SnapShare can read critical, just-written data from the primary database or temporarily return the upload result directly to the user while replicas catch up.

### Trade-off 3: Asynchronous thumbnails versus immediate availability

A message queue allows uploads to finish without waiting for thumbnail creation, improving responsiveness and absorbing temporary spikes in processing demand. The downside is that thumbnails may not be ready immediately, and failed jobs require retries and monitoring. SnapShare can display a placeholder until processing finishes and alert engineers when the queue backlog becomes too large.

### Trade-off 4: Object storage versus simpler database storage

Object storage scales well for large photo files and separates media delivery from structured database operations. However, the application must manage storage keys, permissions, upload completion, cleanup, and consistency between photo records and stored objects. This additional complexity is justified by the expected growth to hundreds of terabytes of new media each year.

## 9. Conclusion

SnapShare has approximately one million daily active users, one million photo uploads per day, and 50 million feed views per day. Its average feed traffic is about 579 requests per second, with an estimated peak of 2,894 requests per second. Original photos and thumbnails add approximately 748.25 TB of storage per year under the stated assumptions.

Because the application is read-heavy, it should prioritize CDN delivery, caching, and read replicas while preserving reliable uploads through object storage and a primary database. A message queue and thumbnail worker separate image processing from the upload request. Horizontal scaling, rate limiting, timeouts, retries, and monitoring help the system handle growth and failures without making the whole service unavailable.

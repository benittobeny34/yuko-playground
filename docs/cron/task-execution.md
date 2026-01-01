---

## 🧩 Task Execution Model

Each task in the Hybrid Cron System implements the `HybridScheduledTask` interface and defines:

- A **unique name** via `name()`
- A **frequency array** (e.g., `['daily']`) via `frequency()`
- A **run method**, which contains the core execution logic

Only tasks whose defined frequency matches the one passed to the `hybrid:run {frequency}` command are executed.

---

## 🔁 How Tasks Are Selected

The `HybridTaskRegistry` holds all available tasks. When the cron command runs, it filters these tasks based on their defined frequency.

| Task Class                  | Frequency |
| --------------------------- | --------- |
| `SendBirthdayEmailsTask`    | daily     |
| `CleanUpExpiredPointsTask`  | monthly   |
| `SendAnniversaryEmailsTask` | daily     |
| `RewardReminderTask`        | daily     |

For example, calling `php artisan hybrid:run daily` will execute three out of four tasks shown above except `CleanUpExpiredPointsTask`.

---

## 📝 Example: SendBirthdayEmailsTask

The `SendBirthdayEmailsTask` is responsible for sending birthday-related emails to users, based on their birth dates.

### Purpose

- Identify users with birthdays matching the current date.
- Dispatch emails in large-scale chunks, split per organization.

### Frequency

- This task runs **daily**.

### Execution Logic

1. **Define a Chunk Size**  
   The system sets a `$chunkSize` of 5,000 users per batch. This defines how many users each background job will handle.

2. **Chunk Organizations**  
   All organizations are fetched from the database in chunks of 1,000. This avoids memory overload when dealing with a large number of organizations.

## Queuing Time Estimates for Organization

| Total Organizations | Chunk Size | Number of Chunks | Average Time per Organization | Estimated Total Dispatch Time |
| ------------------- | ---------- | ---------------- | ----------------------------- | ----------------------------- |
| 2,000               | 1,000      | 2                | 0.5ms – 2ms                   | 1s – 4s                       |
| 10,000              | 1,000      | 10               | 0.5ms – 2ms                   | 5s – 20s                      |
| 20,000              | 1,000      | 20               | 0.5ms – 2ms                   | 10s – 40s                     |

3. **Loop Over Organizations**  
   For each organization in the current chunk:

    - The system attempts to find the **minimum user ID** within that organization using a filtered query (`byOrg($organization->id)`).
    - If a valid user ID exists (i.e., the organization has at least one user), a background job is dispatched.

---

## 📦 DispatchBirthdayChunkRangesJob: Chunked Email Processing

Once the `SendBirthdayEmailsTask` dispatches a `DispatchBirthdayChunkRangesJob`, this job handles processing a chunk of users and queues individual email jobs for each.

### Responsibilities

- Control parallelism to avoid overwhelming the queue or infrastructure.
- Process users in batches starting from a specific user ID.
- Dispatch actual `SendBirthdayEmailJob` jobs for each user in the batch.
- Schedule the **next chunk** after the current batch finishes.

### Step-by-Step Execution

#### 4.1. Concurrency Control

- The job uses a cache-based semaphore (`birthday_chunks_running`) to limit how many chunks run concurrently.
- If more than 5 chunks are running (`$maxConcurrentChunks = 5`), it:
    - Decrements the semaphore count (undoes the increment).
    - Releases the job back to the queue with a **30-second delay**.
    - This retry mechanism ensures controlled load and prevents queue flooding.

#### 4.2. Fetch Users by ID Range

- The job fetches the next **`chunkSize`** (e.g., 5,000) users starting from the given `$startId`.
- Users are ordered by ID to ensure sequential, non-overlapping processing.
- If no users are found, the job exits quietly.

#### 4.3. Create Email Jobs

- For each user in the chunk, a `SendBirthdayEmailJob` is created with that user's ID.
- These are collected into a list of jobs for batch dispatching.

#### 4.4. Dispatch as Batch Job

- Laravel’s `Bus::batch()` is used to queue all the `SendBirthdayEmailJob`s together.
- Once the batch completes (`then()` callback), a **new `DispatchBirthdayChunkRangesJob`** is dispatched:
    - It starts from the last processed user ID + 1.
    - This creates a **recursive loop** that continues dispatching chunks until all users are processed.

---

### ✅ Asynchronous Execution

All heavy lifting (email matching, sending, batching) is handled inside the `DispatchBirthdayChunkRangesJob` job class, allowing the cron task to return quickly and stay lightweight.

---

### 💡 Benefits of This Structure

| Benefit          | Explanation                                                                      |
| ---------------- | -------------------------------------------------------------------------------- |
| Scalable         | Each organization is processed independently, allowing distributed job queues    |
| Memory Efficient | Uses Laravel’s `chunk()` and lazy loading to prevent memory overuse              |
| Queue-Optimized  | Offloads actual work to jobs, avoiding long-running cron locks                   |
| Modular          | Easy to isolate bugs, retry failed batches, or monitor per-org performance       |
| Extendable       | Future logic (like filtering users or prioritizing orgs) can be injected cleanly |

---

## 🚀 Summary

This approach ensures that birthday emails can be sent for **millions of users**, across **thousands of organizations**, without blocking or slowing down your cron system.

Other tasks in the registry follow a similar structure. Each:

- Declares a `name()` for logging and tracking
- Specifies its run frequency
- Implements a `run()` method tailored to its functionality

The goal is to encapsulate each task's logic in a clean, isolated manner that can be independently executed via Laravel’s queue system.

---

---

## Batch Estimation Table for Birthday Email Processing

Each batch handles **5,000 users**. The job recursively continues until all users are processed, chunk by chunk.

| Total Users       | Chunk Size | Total Batches Needed | Description                                            |
| ----------------- | ---------- | -------------------- | ------------------------------------------------------ |
| 1,000,000(1M)     | 5,000      | 200                  | 1 million users will be split into 200 chunks.         |
| 10,000,000(10M)   | 5,000      | 2,000                | 10 million users will require 2,000 recursive batches. |
| 100,000,000(100M) | 5,000      | 20,000               | 100 million users will be processed in 20,000 chunks.  |

---

### How this works

- **Initial Step:** `run()` fetches all `Organization`s and for each:

    - Gets the first user ID (`startId`) matching birthday criteria.
    - Dispatches a `DispatchBirthdayChunkRangesJob` starting at that ID.

- **Chunk Execution (Recursive):**

    - Each `DispatchBirthdayChunkRangesJob`:
        - Fetches 5,000 users starting from `startId`.
        - Queues `SendBirthdayEmailJob` for each user in the chunk.
        - When all 5,000 jobs complete (`Bus::batch()->then()`), it:
            - Dispatches another `DispatchBirthdayChunkRangesJob` with `startId = lastId + 1`.
    - This continues recursively until no users are left.

- **Concurrency Control:**
    - No more than 5 concurrent chunk processors can run at a time (configurable).
    - Excess chunks are deferred by 30 seconds using `$this->release(30)`.

---

### Final Notes

- Each batch of 5,000 users translates to **5,000 individual email jobs**.
- The processing speed and total time depend on:
    - Job queue throughput.
    - Number of concurrent workers.
    - Retry behavior on failure.

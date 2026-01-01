# Laravel Queue Workers: Job Execution and Deduplication

## Overview

This document explains how Laravel queue workers (e.g., using Laravel Horizon) behave when processing jobs — specifically focusing on why multiple workers **do not** pick up the same job even when available concurrently.

We’ll walk through a real-world use case involving recursive job dispatching.

---

## Scenario

You dispatch the following job:

```php
dispatch(new DispatchBirthdayChunkRangesJob('org-1', 1, 5000));
```

And you have **4 Horizon workers** running on the `default` queue.

### Concern

> Why doesn’t the same job get picked up by all 4 workers at the same time?

---

## Core Concepts

### 1. Job Dispatching

When a job is dispatched in Laravel:

```php
dispatch(new SomeJob(...));
```

- The job is **serialized** and pushed to the **queue backend**, e.g., Redis.
- For Redis, the job is pushed to a list such as `queues:default`.
- **Only one copy** of the job is inserted unless explicitly dispatched multiple times.

### 2. Worker Behavior

Laravel workers:

- Continuously **listen** for jobs on the queue.
- Use **atomic operations** like `BRPOP` or `BRPOPLPUSH` (in Redis) to retrieve jobs.
- Ensure that **only one worker can claim a job** at a time.

Even with 4 workers listening on the same queue:

- When a job appears, **only one** worker will successfully pop and reserve it.
- The other workers will continue waiting for the next available job.

---

## Real-World Example: Recursive Job Dispatching

You have a job called `DispatchBirthdayChunkRangesJob`, which:

- Is dispatched once per organization with `startId = 1`.
- Processes a chunk of users (e.g., 5000).
- After processing, it dispatches itself recursively with `startId + chunkSize`.

### Example:

```php
dispatch(new DispatchBirthdayChunkRangesJob('org-1', 1, 5000));
```

This results in the following sequence:

1. The first job for `org-1` with `startId = 1` is dispatched.
2. A single worker picks up and processes the job.
3. The job queries a chunk of users and dispatches follow-up job(s):
    ```php
    dispatch(new DispatchBirthdayChunkRangesJob('org-1', 5001, 5000));
    ```
4. This repeats until no more users are found for that organization.

Each of these recursive jobs is still **only one instance**, and will be picked by **one worker at a time**.

---

## Why Jobs Are Not Duplicated

Even with 4 (or more) workers:

- A job is **only added once** to the queue.
- Workers use atomic operations to fetch jobs — no race conditions.
- Laravel’s queue system ensures **one job = one worker**.

---

## Optional: Preventing Accidental Duplicates with `ShouldBeUnique`

If you want to prevent even accidental duplication of the same job (e.g., duplicate dispatch due to logic errors), you can use the `ShouldBeUnique` interface:

```php
use Illuminate\Contracts\Queue\ShouldBeUnique;

class DispatchBirthdayChunkRangesJob implements ShouldQueue, ShouldBeUnique
{
    public $uniqueFor = 300; // seconds the job should remain unique

    public function uniqueId(): string
    {
        return $this->organizationUuid . '-' . $this->startId;
    }
}
```

This ensures Laravel won't queue multiple instances of the same job (based on the unique ID) during that time frame.

---

## Summary

| Concept                   | Explanation                                                              |
| ------------------------- | ------------------------------------------------------------------------ |
| Job dispatching           | Each `dispatch()` adds one job to the queue                              |
| Worker behavior           | Workers pick one job at a time using atomic Redis operations             |
| Multiple workers          | Only one worker can claim and execute a job                              |
| Recursive job dispatching | Each follow-up job is distinct, only one worker executes it at a time    |
| No duplication            | Because queue operations are atomic and jobs aren’t broadcast to workers |
| Optional deduplication    | Use `ShouldBeUnique` to prevent accidental logic-based duplicates        |

---

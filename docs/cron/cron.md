# Hybrid Cron System

This document outlines the architecture and usage of the **Hybrid Cron System**, which allows running scheduled tasks based on specific frequencies (e.g., hourly, daily, monthly, yearly). This approach provides flexibility and scalability by combining Laravel's queue system with a task registry.

---

## 📌 Overview

The **Hybrid Cron System** separates task registration, scheduling, and execution. It consists of the following components:

| Component               | Responsibility                                                                  |
| ----------------------- | ------------------------------------------------------------------------------- |
| `RunHybridTasksCommand` | Accepts a frequency (e.g., `hourly`, `daily`) and dispatches tasks of that type |
| `HybridTaskRegistry`    | Provides a list of tasks to run for a given frequency                           |
| `RunScheduledTaskJob`   | Executes a single task asynchronously via Laravel's queue system                |
| `HybridScheduledTask`   | Interface that each scheduled task implements (not shown in this snippet)       |

---

## 🧠 Concept

The system is designed to execute a **group of scheduled tasks** based on a **specified frequency** using Laravel queues. This allows long-running or heavy cron tasks to be distributed across workers and retried safely if they fail.

---

## 🧪 Usage

### 1. Register Tasks

Tasks are registered inside the `HybridTaskRegistry`, mapped by their execution frequency (e.g., hourly, daily, weekly).

Each task implements a shared interface or contract, ensuring that all tasks provide:

- A unique `name()`
- A `run()` method that performs the task's actual logic

---

### 2. Schedule the Command

The artisan command `hybrid:run {frequency}` is invoked by Laravel's scheduler.

| Example Scheduler Entry         | Description                      |
| ------------------------------- | -------------------------------- |
| `php artisan hybrid:run hourly` | Triggers all hourly hybrid tasks |
| `php artisan hybrid:run daily`  | Triggers all daily hybrid tasks  |

---

### 3. Task Dispatching

Upon execution, the command:

- Fetches all tasks matching the given frequency from `HybridTaskRegistry`
- Dispatches each task as a job using Laravel's `dispatch()` method
- Each job is handled asynchronously by the queue worker

---

### 4. Job Execution

Each dispatched job is an instance of `RunScheduledTaskJob`. When processed:

- The job logs the task name
- The job calls the task's `run()` method
- Any task failure will follow Laravel's queue retry/failure mechanism

---

## ✅ Benefits

| Feature                       | Description                                                              |
| ----------------------------- | ------------------------------------------------------------------------ |
| Asynchronous execution        | Tasks are dispatched to the queue, improving performance and reliability |
| Frequency-based control       | Tasks are grouped and run based on custom-defined frequency tags         |
| Centralized task registration | All tasks are registered in a single registry (`HybridTaskRegistry`)     |
| Scalable and retryable        | Built on Laravel’s queue system for fault tolerance and scalability      |

---

## 🔒 Notes

- Make sure all tasks implement a consistent interface or base class (`HybridScheduledTask`)
- Laravel queue workers must be running for this system to function correctly
- Logs can be monitored to trace task executions

---

## 🏁 Example Flow

1. Laravel scheduler calls `php artisan hybrid:run daily`
2. The command queries the registry for all daily tasks
3. Each task is dispatched to the queue as a job
4. Laravel queue workers execute each task independently
5. Logs are generated for each execution

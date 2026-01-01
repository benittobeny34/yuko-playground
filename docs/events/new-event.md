# 🚀 Adding a New Event to the Workflow System

This guide provides a step-by-step reference to introduce a **new event** into the application, ensuring it integrates seamlessly with data preparation, condition checks, and event tracking.

---

## 📌 Steps to Add a New Event

### 1. Define the Event Constant

- **File**: `App\WorkFlows\Events\EventList`
- **Action**: Add a new constant representing your event.

```php
public const YOUR_EVENT_NAME = 'your_event_name';
```

---

### 2. Update Event Class Lookup

- **File**: `App\WorkFlows\Events\EventList::getEventClasses()`
- **Action**: Map the new constant to the event class.

```php
self::YOUR_EVENT_NAME => YourEvent::class,
```

---

### 4. Add Resolver for Event Data Preparer

EventDataPreparerFactory resolver

### 3. Create the Event Class

- **Location**: `App\WorkFlows\Events`
- **Class Name**: `YourEvent`
- **Implements**: Base Event contract
- **Responsibilities**: Event metadata (e.g., name, group, available fields, etc.)

---

### 4. Create the Event Data Preparer Class

- **Location**: `App\Services\Events\DataPreparer`
- **Class Name**: `YourEventDataPreparer`
- **Responsibilities**:
    - Extract event-specific data
    - Determine unique identifier
    - Set `customer_id` and other required fields
- **Implements**: Base `EventDataPreparerInterface`

---

### 5. Register in Eventless Configuration (if applicable)

- **Location**: `App\Services\Workflows\Events`
- **Action**: If the event doesn't trigger from the app naturally, add to the eventless trigger list.

---

### 6. Create Event DataPreparer Class for Workflow

- **Location**: `workflow-engine/datapreparer/events`
- **Class Name**: `{EventName}Preparer`
- **Responsibilities**: Prepares field values for condition checking within workflow engine.

---

### 7. Implement Field Data Preparer Logic

> 🚨 _This will be deprecated soon, but currently required._

- **Location**: `workflow-engine/condition-check/data-preparation/data-preparer/strategies/{field}/`
- **Class Name**: `{YourEventFieldDataPreparer}`
- **Responsibilities**: Construct field-level condition data for the event
- **Also Update**: Relevant field preparer registry/list

---

## ✅ Summary Checklist

| Task                            | File/Path                               | Done |
| ------------------------------- | --------------------------------------- | ---- |
| Add event constant              | `EventList`                             | ☐    |
| Update `getEventClasses()`      | `EventList`                             | ☐    |
| Create event class              | `App\WorkFlows\Events`                  | ☐    |
| Create data preparer            | `App\Services\Events\DataPreparer`      | ☐    |
| Implement logic in preparer     | `YourEventDataPreparer`                 | ☐    |
| Create workflow engine preparer | `workflow-engine/datapreparer/events`   | ☐    |
| Create field data preparer      | `workflow-engine/.../strategies/field/` | ☐    |
| Update field preparer registry  | `strategies/index file`                 | ☐    |

---

## 🧪 Testing & Validation

1. Simulate the event in a dev environment.
2. Ensure it gets recorded in the `events` table.
3. Test workflows using this event to verify data preparation and condition checks work.
4. Monitor Horizon/Queue logs for any failure in the data preparers.

---

## 🛠 Example

**Event**: `REVIEW_APPROVED`

1. Add to `EventList`:

```php
public const REVIEW_APPROVED = 'review_approved';
```

2. Map in `getEventClasses()`:

```php
self::REVIEW_APPROVED => ReviewApproved::class,
```

3. Create `ReviewApproved.php` in `App\WorkFlows\Events`.

4. Create `ReviewApprovedDataPreparer.php` in `App\Services\Events\DataPreparer`.

5. Create `ReviewApprovedPreparer.php` in `workflow-engine/datapreparer/events`.

6. Add field preparers in `workflow-engine/.../strategies/review_approved/`.

---

## 📎 Notes

- Follow consistent naming conventions (`PascalCase` for class names, `snake_case` for event constants).
- Try to decouple logic inside preparers — use helpers/services as needed.
- Upcoming refactor will remove **field-level data preparers** — watch for migration updates.

---

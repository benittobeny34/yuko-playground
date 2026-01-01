# 🚀 Hierarchical Review Cache Architecture

## Supports:
- Product-level reviews
- Product Group reviews (shared across multiple products)
- Store Syndication reviews (shared across multiple orgs/stores)
- Rating filters
- Metadata
- High-performance Redis retrieval

---

## 📌 Overview

This caching architecture organizes review storage and lookup across three levels:

1. **Product Level** – reviews belonging to a single product inside a single org.
2. **Product Group Level** – reviews shared across grouped products inside an org.
3. **Store Syndication Level** – reviews shared across multiple stores/orgs.

Each level supports:
- review ID lists
- rating-based lists
- metadata
- by-rating summaries

---

## 🧱 1. Review-Level Cache (Canonical Source)

Each review is stored individually for fast lookup:

### Key Pattern
```
reviews:review:{review_id}
```

### Structure (JSON)
```json
{
  "id": "...",
  "rating": 5,
  "body": "Great product!",
  "product_id": "PID100",
  "org_id": "ORG-A",
  "created_at": "...",
  "images": [...]
}
```

> **Note:** All other caches reference this key.

---

## 🧱 2. Organization-Level Product Cache

Reviews directly belonging to a product inside a specific organization.

### Key Patterns

| Type | Key Pattern |
|------|-------------|
| **Base Key** | `reviews:org:{org_id}:product:{product_id}` |
| **Rating Filter** | `reviews:org:{org_id}:product:{product_id}:rating:{rating}` |
| **Metadata** | `reviews:org:{org_id}:product:{product_id}:meta_data` |
| **By Rating Summary** | `reviews:org:{org_id}:product:{product_id}:by_rating` |

---

## 🧱 3. Organization-Level Product Group Cache

Multiple products can form a product group, allowing them to share reviews.

### Key Patterns

| Type | Key Pattern |
|------|-------------|
| **Base Key** | `reviews:org:{org_id}:product_group:{product_group_id}` |
| **Rating Filter** | `reviews:org:{org_id}:product_group:{product_group_id}:rating:{rating}` |
| **Metadata** | `reviews:org:{org_id}:product_group:{product_group_id}:meta_data` |
| **By Rating Summary** | `reviews:org:{org_id}:product_group:{product_group_id}:by_rating` |

---

## 🧱 4. Store Syndication Cache

**Store-level review sharing across multiple orgs**

A store syndication group is a collection of orgs where reviews are shared across stores.

### Product Group Level Keys

| Type | Key Pattern |
|------|-------------|
| **Base Key** | `reviews:syndication_group:{syndication_group_id}:product_group:{product_group_id}` |
| **Rating Filter** | `reviews:syndication_group:{syndication_group_id}:product_group:{product_group_id}:rating:{rating}` |

### Shared Keys Across Levels (Optional)

| Type | Key Pattern |
|------|-------------|
| **Metadata** | `reviews:syndication_group:{syndication_group_id}:meta_data` |
| **By Rating Summary** | `reviews:syndication_group:{syndication_group_id}:by_rating` |

---

## ⚙️ Review Insertion Workflow

When a review is created for:

```
ORG A → Product PID100 → Review RID1
```

### Step 1 — Store canonical review

```redis
SET reviews:review:RID1 {json}
```

### Step 2 — Product-level cache

```redis
LPUSH reviews:org:A:product:PID100 RID1
```

### Step 3 — Product group cache (if product belongs to groups)

For groups G20, G30:

```redis
LPUSH reviews:org:A:product_group:G20 RID1
LPUSH reviews:org:A:product_group:G30 RID1
```

### Step 4 — Syndication group cache (if org belongs to SG700)

```redis
LPUSH reviews:syndication_group:700:product:PID100 RID1
LPUSH reviews:syndication_group:700:product_group:G20 RID1
LPUSH reviews:syndication_group:700:product_group:G30 RID1
```

---

## 🔍 Widget Fetch Logic

**Given:**
- `product_id = X`
- `org_id = A`

**Priority-based resolution:**

### 1️⃣ Is the org part of a syndication group?

**Use:**
```
reviews:syndication_group:{syndication_group_id}:product:{product_id}
OR
reviews:syndication_group:{syndication_group_id}:product_group:{product_group_id}
```

### 2️⃣ Else, is the product part of a product group?

**Use:**
```
reviews:org:{org_id}:product_group:{product_group_id}
```

### 3️⃣ Else, fallback to product-level cache

**Use:**
```
reviews:org:{org_id}:product:{product_id}
```

---

## 🧠 Summary Diagram (Conceptual)

```
                   +------------------------+
                   |   Store Syndication    |
                   | reviews:synd_group:*   |
                   +-----------+------------+
                               |
                    (org shared across stores)
                               |
                +--------------+--------------+
                | Product Groups (org level)  |
                | reviews:org:X:product_group |
                +--------------+--------------+
                               |
                     (product grouped)
                               |
                   +-----------+------------+
                   | Product-Level Reviews  |
                   | reviews:org:X:product  |
                   +------------------------+
```

---

## 📝 Additional Considerations

### Cache Expiration/TTL
- Define TTL strategies for different cache levels
- Consider using `EXPIRE` or `SETEX` for time-based invalidation

### Cache Invalidation
When a review is updated/deleted:
- Invalidate `reviews:review:{review_id}`
- Invalidate all associated list caches (product, product_group, syndication_group)
- Recalculate metadata and by_rating summaries

### Pagination
Use `LRANGE` for paginating large review lists:
```redis
LRANGE reviews:org:{org_id}:product:{product_id} 0 9  # First 10 reviews
```

### Sorting
Reviews should be sorted by:
- **Default:** `created_at` (newest first)
- **Optional:** rating, helpfulness score

---

## 🔧 Implementation Checklist

- [ ] Implement canonical review storage
- [ ] Implement product-level cache
- [ ] Implement product group cache
- [ ] Implement syndication group cache
- [ ] Add rating filter support
- [ ] Add metadata calculation
- [ ] Add by-rating summary calculation
- [ ] Implement cache invalidation logic
- [ ] Add pagination support
- [ ] Add sorting options
- [ ] Define TTL policies
- [ ] Add monitoring/metrics

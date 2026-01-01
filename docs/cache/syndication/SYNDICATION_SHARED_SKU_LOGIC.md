# Syndication Shared SKU Logic

## 🎯 Core Principle

**Only cache reviews for SKUs that exist in MULTIPLE organizations within the syndication group.**

If a SKU only exists in one org, it's NOT syndicated (remains org-level only).

## 🤔 Why?

**Syndication is meant to share reviews across stores selling the same products.**

- ✅ **SKU "TSHIRT-BLUE-M"** exists in Org A, Org B, Org C → **SYNDICATE**
- ❌ **SKU "CUSTOM-ITEM-123"** exists only in Org A → **DON'T SYNDICATE**

This prevents:
- Caching reviews for products unique to one store
- Wasting Redis memory on non-shared SKUs
- Showing irrelevant reviews from different products

## 📊 Example Scenario

### Group Setup

**Syndication Group:** "Fashion Brands"
- **Org A** (Store A)
- **Org B** (Store B)
- **Org C** (Store C)

### Products

| SKU | Org A | Org B | Org C | Syndicated? |
|-----|-------|-------|-------|-------------|
| `TSHIRT-BLUE-M` | ✅ | ✅ | ✅ | ✅ YES (3 orgs) |
| `JEANS-SLIM-32` | ✅ | ✅ | ❌ | ✅ YES (2 orgs) |
| `HAT-RED-ONE` | ✅ | ❌ | ❌ | ❌ NO (1 org only) |
| `CUSTOM-LOGO-A` | ✅ | ❌ | ❌ | ❌ NO (1 org only) |

### Reviews

**Org A:**
- 50 reviews for `TSHIRT-BLUE-M` → **Cached in syndication** ✅
- 30 reviews for `JEANS-SLIM-32` → **Cached in syndication** ✅
- 10 reviews for `HAT-RED-ONE` → **NOT cached in syndication** ❌ (org-level only)

**Org B:**
- 40 reviews for `TSHIRT-BLUE-M` → **Cached in syndication** ✅
- 20 reviews for `JEANS-SLIM-32` → **Cached in syndication** ✅

**Org C:**
- 25 reviews for `TSHIRT-BLUE-M` → **Cached in syndication** ✅

### Syndication Cache Result

```redis
# TSHIRT-BLUE-M (115 total reviews from 3 orgs)
ZCARD reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M
→ 115

# JEANS-SLIM-32 (50 total reviews from 2 orgs)
ZCARD reviews:syndication_group:GROUP-123:product_group:JEANS-SLIM-32
→ 50

# HAT-RED-ONE (NOT in syndication cache)
ZCARD reviews:syndication_group:GROUP-123:product_group:HAT-RED-ONE
→ 0 (key doesn't exist)
```

## 🔍 Implementation Details

### 1. Full Group Recache

When recaching entire group (`recacheSyndicationGroup`):

```php
// Step 1: Find shared SKUs (exist in ≥2 orgs)
$sharedSkus = DB::table('products')
    ->select('sku', DB::raw('COUNT(DISTINCT org_uuid) as org_count'))
    ->whereIn('org_uuid', $orgUuids)
    ->whereNotNull('sku')
    ->whereNull('parent_uuid')
    ->groupBy('sku')
    ->having('org_count', '>=', 2) // Must be in at least 2 orgs
    ->pluck('sku');

// Step 2: Only cache reviews for shared SKUs
$reviewsBySku = DB::table('reviews')
    ->join('products', ...)
    ->whereIn('products.sku', $sharedSkus) // Filter!
    ->get()
    ->groupBy('sku');

// Step 3: Double-check reviews come from multiple orgs
foreach ($reviewsBySku as $sku => $reviews) {
    $uniqueOrgs = collect($reviews)->pluck('org_uuid')->unique()->count();

    if ($uniqueOrgs >= 2) {
        // Cache it
    } else {
        // Skip it
    }
}
```

### 2. Single Org Recache

When org joins group (`recacheOrganizationReviews`):

```php
// Step 1: Get other orgs in group
$otherOrgUuids = array_filter($allOrgUuids, fn($u) => $u !== $newOrgUuid);

// Step 2: Find SKUs from new org that exist in other orgs
$sharedSkus = DB::table('products as p1')
    ->join('products as p2', 'p1.sku', '=', 'p2.sku')
    ->where('p1.org_uuid', $newOrgUuid)
    ->whereIn('p2.org_uuid', $otherOrgUuids)
    ->where('p1.org_uuid', '!=', 'p2.org_uuid')
    ->distinct()
    ->pluck('p1.sku');

// Step 3: Only cache reviews for shared SKUs
$reviewsBySku = DB::table('reviews')
    ->join('products', ...)
    ->where('reviews.org_uuid', $newOrgUuid)
    ->whereIn('products.sku', $sharedSkus) // Filter!
    ->get();
```

### 3. Real-Time Review Caching

When a new review is created (`UpdateReviewCache`):

```php
// Get product SKU
$product = $review->product;

// Get syndication group
$syndicationGroup = ...;

// Get other orgs in group
$otherOrgUuids = array_filter($allOrgUuids, fn($u) => $u !== $review->org_uuid);

// Check if SKU exists in at least one other org
$skuExistsInOtherOrg = DB::table('products')
    ->whereIn('org_uuid', $otherOrgUuids)
    ->where('sku', $product->sku)
    ->exists();

if (!$skuExistsInOtherOrg) {
    return; // Don't cache in syndication
}

// Cache it
$syndicationCacheService->cacheReviewInSyndication(...);
```

## 🎭 Real-World Examples

### Example 1: T-Shirt Sellers

**Group:** "T-Shirt Alliance"
- **Store A:** Urban Fashion (sells 100 SKUs)
- **Store B:** Campus Wear (sells 80 SKUs)
- **Store C:** Sports Gear (sells 120 SKUs)

**Shared SKUs:** 25 SKUs (popular designs sold by all)

**Result:**
- ✅ Only the 25 shared SKUs get syndication cache
- ❌ Store A's 75 unique SKUs remain org-level only
- ❌ Store B's 55 unique SKUs remain org-level only
- ❌ Store C's 95 unique SKUs remain org-level only

**Efficiency:**
- Without filtering: 300 SKUs × reviews = huge cache
- With filtering: 25 SKUs × reviews = optimized cache

### Example 2: Multi-Brand Retailer

**Group:** "Electronics Hub"
- **Store A:** Phone Accessories (1000 SKUs, 5000 reviews)
- **Store B:** Computer Parts (800 SKUs, 3000 reviews)
- **Store C:** Home Audio (600 SKUs, 2000 reviews)

**Shared SKUs:** 50 SKUs (popular items like USB cables, chargers)

**Result:**
- ✅ 50 shared SKUs with ~500 total reviews syndicated
- ❌ 2350 unique SKUs with 9500 reviews NOT syndicated
- **Saves:** 95% of cache space!

## 🚀 Performance Benefits

### Memory Savings

**Without Shared SKU Logic:**
```
5 orgs × 1000 SKUs each × 10 reviews avg = 50,000 cache entries
```

**With Shared SKU Logic:**
```
5 orgs × 100 shared SKUs × 10 reviews avg = 5,000 cache entries
90% memory savings!
```

### Query Efficiency

**Full Recache Without Filtering:**
```sql
-- Query ALL products from all orgs
SELECT * FROM products WHERE org_uuid IN (...)
→ 5000 products

-- Cache ALL reviews
SELECT * FROM reviews WHERE product_uuid IN (...)
→ 50,000 reviews
```

**Full Recache With Filtering:**
```sql
-- Find shared SKUs first
SELECT sku, COUNT(DISTINCT org_uuid) FROM products
WHERE org_uuid IN (...)
GROUP BY sku
HAVING COUNT(DISTINCT org_uuid) >= 2
→ 500 shared SKUs

-- Cache only shared reviews
SELECT * FROM reviews WHERE product_uuid IN (
  SELECT uuid FROM products WHERE sku IN (shared_skus)
)
→ 5,000 reviews (10x less!)
```

## 🧪 Testing Scenarios

### Test 1: Group Creation (Single Org)

```php
// Org A creates group
POST /api/v1/reviews/syndication/groups
{
  "name": "Test Group"
}

// Org A has products: SKU-1, SKU-2, SKU-3
// Result: NO syndication cache (no other orgs yet)
```

**Expected:**
```redis
KEYS reviews:syndication_group:*
→ (empty)
```

### Test 2: Second Org Joins (Shared SKUs)

```php
// Org B joins with shared SKU-1, SKU-2
POST /api/v1/reviews/syndication/groups/join
{
  "token": "..."
}

// Result: Only SKU-1 and SKU-2 get syndicated
```

**Expected:**
```redis
EXISTS reviews:syndication_group:GROUP:product_group:SKU-1
→ 1

EXISTS reviews:syndication_group:GROUP:product_group:SKU-2
→ 1

EXISTS reviews:syndication_group:GROUP:product_group:SKU-3
→ 0 (not shared)
```

### Test 3: New Review for Shared SKU

```php
// Org A creates review for SKU-1
// SKU-1 exists in Org B

// Result: Cached in both org-level AND syndication
```

**Expected:**
```redis
# Org-level cache
EXISTS reviews:organization:ORG-A:product:{uuid}
→ 1

# Syndication cache
ZSCORE reviews:syndication_group:GROUP:product_group:SKU-1 "ORG-A:review-123"
→ {timestamp}
```

### Test 4: New Review for Non-Shared SKU

```php
// Org A creates review for SKU-3
// SKU-3 only exists in Org A

// Result: Cached ONLY in org-level, NOT in syndication
```

**Expected:**
```redis
# Org-level cache
EXISTS reviews:organization:ORG-A:product:{uuid}
→ 1

# Syndication cache
ZSCORE reviews:syndication_group:GROUP:product_group:SKU-3 "ORG-A:review-456"
→ nil (doesn't exist)
```

## 📝 Best Practices

### ✅ Do

- Ensure products have proper SKUs before joining syndication
- Use consistent SKU formats across organizations
- Regularly audit shared SKUs vs unique SKUs
- Monitor syndication cache size

### ❌ Don't

- Don't create groups with orgs that have no shared SKUs
- Don't use random/unique SKUs if you want syndication
- Don't manually add reviews to syndication cache
- Don't expect single-org SKUs to be syndicated

## 🎉 Summary

The shared SKU logic ensures:

✅ **Relevance** - Only truly shared products are syndicated
✅ **Efficiency** - Minimal cache usage
✅ **Performance** - Fewer queries, less data
✅ **Accuracy** - Reviews only shown where products match

**Result:** Smart, efficient review syndication! 🚀

---

**Implementation Date:** December 19, 2025
**Status:** ✅ Complete with Shared SKU Filtering

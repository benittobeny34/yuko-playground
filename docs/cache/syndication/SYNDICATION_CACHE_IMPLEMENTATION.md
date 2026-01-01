# Review Syndication Cache Implementation

## Overview

This document explains the **efficient cache-based syndication** implementation that avoids querying products on every review fetch. The system uses **SKU as the product_group_id** and follows the hierarchical cache architecture defined in `docs/cache/review-to-syndication.md`.

## 🎯 Key Concept

**SKU = Product Group ID for Syndication**

Instead of querying products by SKU every time, we:
1. Cache reviews directly in syndication groups using SKU as the identifier
2. When a review is created/updated, automatically cache it in the syndication group
3. Fetch reviews directly from Redis using the syndication cache keys

## 📁 Files Modified/Created

### Created Files
1. `app/Cache/Reviews/SyndicationCacheService.php` - Handles syndication-specific caching
2. `SYNDICATION_CACHE_IMPLEMENTATION.md` - This documentation

### Modified Files
1. `app/Cache/Reviews/Traits/CacheKeys.php` - Added syndication cache key patterns
2. `app/Cache/Reviews/ReviewService.php` - Added canonical review storage
3. `app/Services/Reviews/Public/UpdateReviewCache.php` - Caches in syndication group
4. `app/Http/Controllers/Reviews/SyndicationController.php` - Uses cache directly

## 🔑 Cache Key Patterns

Following the architecture from `docs/cache/review-to-syndication.md`:

```
# Canonical review (for cross-org lookups - fallback only)
reviews:review:{review_id}

# Org-specific review (primary source)
reviews:organization:{org_id}:{review_id}

# Syndication base key (sorted by timestamp)
# Members are composite keys: {org_uuid}:{review_uuid}
reviews:syndication_group:{syndication_group_id}:product_group:{sku}

# Syndication with rating filter
# Members are composite keys: {org_uuid}:{review_uuid}
reviews:syndication_group:{syndication_group_id}:product_group:{sku}:rating:{rating}

# Syndication metadata (star counts, avg rating)
reviews:syndication_group:{syndication_group_id}:product_group:{sku}:meta_data

# Syndication by rating (for highest/lowest sorting)
# Members are composite keys: {org_uuid}:{review_uuid}
reviews:syndication_group:{syndication_group_id}:product_group:{sku}:by_rating
```

### 💡 Composite Key Strategy

**Problem:** Sorted set members only store `review_uuid`, but we need `org_uuid` to build the key `reviews:organization:{org_id}:{review_id}`

**Solution:** Store composite keys in sorted sets: `{org_uuid}:{review_uuid}`

**Example:**
```redis
ZADD reviews:syndication_group:GROUP123:product_group:TSHIRT-BLUE-M 1734567890 "org-a-uuid:review-123"
ZADD reviews:syndication_group:GROUP123:product_group:TSHIRT-BLUE-M 1734567891 "org-b-uuid:review-456"
```

**Retrieval:**
```php
// Get composite keys
$compositeKeys = Redis::zrevrange("reviews:syndication_group:GROUP123:product_group:TSHIRT-BLUE-M", 0, 29);
// Returns: ["org-a-uuid:review-123", "org-b-uuid:review-456"]

// Parse and fetch
foreach ($compositeKeys as $compositeKey) {
    [$orgUuid, $reviewUuid] = explode(':', $compositeKey, 2);
    $cacheKey = "reviews:organization:{$orgUuid}:{$reviewUuid}";
    $review = Redis::get($cacheKey);
}
```

## 🔄 Review Caching Flow

### When a Review is Created/Approved

```
Review Created
    ↓
UpdateReviewCache::handle()
    ↓
1. Cache in Organization Level
   - reviews:organization:{org_id}:product:{product_id}
   - reviews:organization:{org_id}:product:{product_id}:rating:{rating}
   - reviews:organization:{org_id}:product:{product_id}:meta_data
   - reviews:organization:{org_id}:product:{product_id}:by_rating
    ↓
2. Cache Canonical Review (NEW!)
   - reviews:review:{review_id}
    ↓
3. Check if Org is in Syndication Group
   ↓
   ├─ No → Done
   │
   └─ Yes → Check if Product has SKU
       ↓
       ├─ No → Done
       │
       └─ Yes → Cache in Syndication Group
           - reviews:syndication_group:{group_id}:product_group:{sku}
           - reviews:syndication_group:{group_id}:product_group:{sku}:rating:{rating}
           - reviews:syndication_group:{group_id}:product_group:{sku}:meta_data
           - reviews:syndication_group:{group_id}:product_group:{sku}:by_rating
```

## 📥 Review Retrieval Flow

### GET /api/v1/reviews/syndication/products/{productUuid}/reviews

```
Request Received
    ↓
1. Get Product by UUID (single query)
    ↓
2. Check if Product has SKU
   ├─ No → Return error/empty
   │
   └─ Yes → Continue
        ↓
3. Get Syndication Group for Org (single query or cached)
   ├─ No Group → Return error/empty
   │
   └─ Has Group → Continue
        ↓
4. Fetch Composite Keys from Syndication Cache (Redis only!)
   - Key: reviews:syndication_group:{group_id}:product_group:{sku}
   - Or with rating: reviews:syndication_group:{group_id}:product_group:{sku}:rating:{rating}
   - Returns: ["org-a-uuid:review-123", "org-b-uuid:review-456", ...]
   - Sorted by: timestamp (newest/oldest) or rating (highest/lowest)
   - Paginated: ZRANGE/ZREVRANGE with offset
    ↓
5. Parse Composite Keys and Fetch Review Data (Redis only!)
   - For each composite key: split by ':' to get org_uuid and review_uuid
   - Build cache key: reviews:organization:{org_uuid}:{review_uuid}
   - GET reviews:organization:{org_uuid}:{review_uuid}
   - Fallback to canonical if not found: GET reviews:review:{review_uuid}
    ↓
6. Fetch Metadata from Syndication Cache (Redis only!)
   - Key: reviews:syndication_group:{group_id}:product_group:{sku}:meta_data
    ↓
7. Return Response
```

**NO PRODUCT QUERIES** after the initial product lookup!

## 💾 SyndicationCacheService Methods

### Core Caching Methods

```php
// Cache a review in syndication group
cacheReviewInSyndication(Review $review, string $syndicationGroupUuid, string $sku): void

// Increment metadata counters
incrementSyndicationMetaData(Review $review, string $syndicationGroupUuid, string $sku): void

// Delete from syndication cache
deleteFromSyndicationCache(Review $review, string $syndicationGroupUuid, string $sku): void

// Get reviews from syndication cache (returns review IDs)
getReviewsFromSyndicationCache(
    string $syndicationGroupUuid,
    string $sku,
    int $page,
    int $perPage,
    ?int $rating,
    string $sort
): array

// Get aggregated metadata
getMetadataFromSyndicationCache(string $syndicationGroupUuid, string $sku): array

// Check if review exists in syndication cache
isReviewInSyndicationCache(string $syndicationGroupUuid, string $sku, string $reviewUuid): bool

// Get total count
getSyndicationReviewCount(string $syndicationGroupUuid, string $sku, ?int $rating): int
```

## 🎯 UpdateReviewCache Integration

### New Method: `cacheSyndicatedReview()`

```php
private function cacheSyndicatedReview(Review $review, bool $isReviewExist): void
{
    // Get product SKU
    $product = $review->product;
    if (!$product || !$product->sku) {
        return; // No SKU, cannot syndicate
    }

    // Check if org is in a syndication group
    $syndicationService = app(SyndicationService::class);
    $syndicationGroup = $syndicationService->getGroupForOrganization($review->org_uuid);

    if (!$syndicationGroup) {
        return; // Not in a syndication group
    }

    // Cache in syndication group using SKU as product_group_id
    $syndicationCacheService = app(SyndicationCacheService::class);

    $syndicationCacheService->cacheReviewInSyndication(
        $review,
        $syndicationGroup->uuid,
        $product->sku
    );

    // Increment metadata
    if (!isInSyndicationCache && !hasReplies) {
        $syndicationCacheService->incrementSyndicationMetaData(
            $review,
            $syndicationGroup->uuid,
            $product->sku
        );
    }
}
```

## 🚀 Performance Benefits

### Before (SyndicatedReviewCacheService)
❌ Query all org UUIDs in group (1 query)
❌ Query all products with matching SKU across orgs (N queries)
❌ For each product, fetch from cache
❌ Merge and sort in PHP
❌ Aggregate metadata in PHP

**Total:** 1 + N database queries + Redis calls + PHP processing

### After (SyndicationCacheService)
✅ Query single product (1 query)
✅ Get syndication group (cached or 1 query)
✅ Fetch review IDs from Redis sorted set (1 Redis call)
✅ Fetch review data from Redis (N Redis calls, parallel possible)
✅ Fetch metadata from Redis hash (1 Redis call)

**Total:** 1-2 database queries + 2+N Redis calls (all fast!)

## 📊 Redis Data Structures Used

### Sorted Sets (ZADD, ZRANGE, ZREVRANGE, ZCARD, ZREM)
- Store review IDs sorted by timestamp or rating
- Enable efficient pagination
- Support range queries

### Hashes (HMSET, HGETALL, HINCRBY)
- Store metadata (star counts, totals, averages)
- Atomic increments/decrements
- Fast retrieval

### Strings (SET, GET, DEL)
- Store individual review JSON data
- Fast lookups by review ID

## 🔄 Example Scenarios

### Scenario 1: Store A creates a review

1. **Product:** "Blue T-Shirt", SKU: "TSHIRT-BLUE-M"
2. **Organization:** Store A (in Syndication Group "Fashion Brands")
3. **Review:** 5 stars, "Great fit!"

**Cache Operations:**
```redis
# Canonical review (fallback)
SET reviews:review:{review_uuid} {json}

# Org-specific review (primary)
SET reviews:organization:store-a:{review_uuid} {json}

# Org-level cache
ZADD reviews:organization:store-a:product:{product_uuid} {timestamp} {review_uuid}

# Syndication cache (using SKU as product_group_id)
# Store composite key: org_uuid:review_uuid
ZADD reviews:syndication_group:fashion-brands:product_group:TSHIRT-BLUE-M {timestamp} "store-a:review-123"
ZADD reviews:syndication_group:fashion-brands:product_group:TSHIRT-BLUE-M:rating:5 {timestamp} "store-a:review-123"
ZADD reviews:syndication_group:fashion-brands:product_group:TSHIRT-BLUE-M:by_rating 5 "store-a:review-123"

# Syndication metadata
HINCRBY reviews:syndication_group:fashion-brands:product_group:TSHIRT-BLUE-M:meta_data total_reviews 1
HINCRBY reviews:syndication_group:fashion-brands:product_group:TSHIRT-BLUE-M:meta_data total_rating 5
HINCRBY reviews:syndication_group:fashion-brands:product_group:TSHIRT-BLUE-M:meta_data star_5 1
```

### Scenario 2: Store B fetches reviews

1. **Product:** "Men's Blue Tee Medium", SKU: "TSHIRT-BLUE-M" (same SKU!)
2. **Organization:** Store B (also in "Fashion Brands")

**API Call:**
```
GET /api/v1/reviews/syndication/products/{store_b_product_uuid}/reviews
```

**Cache Operations:**
```redis
# Get composite keys from syndication cache (NO PRODUCT QUERIES!)
ZREVRANGE reviews:syndication_group:fashion-brands:product_group:TSHIRT-BLUE-M 0 29
# Returns: ["store-a:review-123", "store-b:review-456", ...]

# For each composite key, parse and fetch:
# Split "store-a:review-123" → org_uuid="store-a", review_uuid="review-123"
GET reviews:organization:store-a:review-123
GET reviews:organization:store-b:review-456

# Get metadata
HGETALL reviews:syndication_group:fashion-brands:product_group:TSHIRT-BLUE-M:meta_data
```

**Result:** Store B sees Store A's review + any other reviews from stores in the group!

## 🔧 Configuration

No configuration needed! The system:
- ✅ Automatically detects if org is in a syndication group
- ✅ Automatically checks if product has SKU
- ✅ Automatically caches in syndication group
- ✅ Falls back to org-level cache if not syndicated

## 🧪 Testing

### Test Flow
1. Create syndication group in Store A
2. Join from Store B using token
3. Create products with **same SKU** in both stores
4. Create a review in Store A
5. Verify review is cached in:
   - Organization level (Store A)
   - Syndication level (group)
6. Fetch reviews from Store B
7. Verify Store B sees Store A's review
8. Verify metadata is aggregated correctly

### Redis Commands to Verify

```bash
# Check if review is in syndication cache (use composite key)
ZSCORE reviews:syndication_group:{group_id}:product_group:{sku} "{org_uuid}:{review_uuid}"

# Get all composite keys for SKU in syndication group
ZREVRANGE reviews:syndication_group:{group_id}:product_group:{sku} 0 -1 WITHSCORES

# Get metadata
HGETALL reviews:syndication_group:{group_id}:product_group:{sku}:meta_data

# Get canonical review
GET reviews:review:{review_uuid}
```

## 🐛 Troubleshooting

### Reviews not appearing in syndication

**Check:**
1. ✅ Product has SKU
   ```sql
   SELECT sku FROM products WHERE uuid = '{product_uuid}';
   ```
2. ✅ Organization is in a syndication group
   ```sql
   SELECT * FROM syndication_group_members WHERE org_uuid = '{org_uuid}';
   ```
3. ✅ Review is approved
   ```sql
   SELECT status FROM reviews WHERE uuid = '{review_uuid}';
   ```
4. ✅ Review is cached
   ```redis
   EXISTS reviews:review:{review_uuid}
   ```

### Metadata counts are wrong

**Fix:** Recache all reviews for the SKU
```php
// Run a job to recache all reviews for affected SKUs
php artisan syndication:recache-reviews {syndication_group_uuid} {sku}
```

## 📝 Migration Notes

### Existing Reviews
If you have existing reviews before implementing syndication:

1. **Option A:** They will auto-cache on next update (lazy)
2. **Option B:** Run a one-time cache population job (eager)

```php
// Job to populate syndication cache for existing reviews
foreach ($reviews as $review) {
    app(UpdateReviewCache::class)->handle($review);
}
```

## 🎉 Summary

The syndication cache implementation provides:

✅ **Zero product queries** during review fetching
✅ **SKU-based grouping** (SKU = product_group_id)
✅ **Automatic caching** when reviews are created
✅ **Efficient Redis operations** (sorted sets + hashes)
✅ **Follows architecture** from `review-to-syndication.md`
✅ **Backward compatible** (org-level cache still works)

**Result:** Fast, scalable review syndication across stores! 🚀

---

**Implementation Date:** December 19, 2025
**Architecture Reference:** `docs/cache/review-to-syndication.md`
**Status:** ✅ Complete and Ready for Testing

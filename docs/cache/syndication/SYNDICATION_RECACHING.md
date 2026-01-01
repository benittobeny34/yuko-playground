# Syndication Recaching Strategy

## 🎯 Problem

When syndication group membership changes, the cache needs to be updated:
- ✅ **Group Created** → Cache owner's reviews
- ✅ **Org Joins** → Add their reviews to cache
- ✅ **Org Leaves** → Remove their reviews from cache
- ✅ **Group Deleted** → Clear all cache

Without recaching, reviews won't appear/disappear when organizations join or leave groups.

## 📋 Solution Overview

**Automatic recaching** integrated into `SyndicationService`:
- When actions happen, cache is automatically updated
- Efficient batch processing grouped by SKU
- Uses Redis SCAN for safe cache clearing
- No manual intervention needed (but available if needed)

## 🔄 Automatic Recaching Flow

### 1. Group Created

```php
POST /api/v1/reviews/syndication/groups
{
  "name": "Fashion Brands"
}

↓ SyndicationService::createGroup()
  ↓ Create group
  ↓ Add owner as member
  ↓ SyndicationRecacheService::recacheOrganizationReviews()
    ↓ Query all approved reviews with SKUs from this org
    ↓ Group by SKU
    ↓ Batch insert into syndication cache
    ↓ Update metadata
```

**What gets cached:**
- All approved reviews from owner org
- Only products with SKUs
- Grouped by SKU for efficient lookup

### 2. Organization Joins

```php
POST /api/v1/reviews/syndication/groups/join
{
  "token": "abc123..."
}

↓ SyndicationService::joinGroup()
  ↓ Verify token and group status
  ↓ Add organization as member
  ↓ SyndicationRecacheService::recacheOrganizationReviews()
    ↓ Query all approved reviews with SKUs from joining org
    ↓ Group by SKU
    ↓ Add to existing syndication cache keys
    ↓ Increment metadata
```

**What gets cached:**
- All approved reviews from joining org
- Added to existing SKU caches
- Metadata updated (counts, ratings)

### 3. Organization Leaves

```php
POST /api/v1/reviews/syndication/groups/leave

↓ SyndicationService::leaveGroup()
  ↓ Verify not owner
  ↓ SyndicationRecacheService::removeOrganizationFromCache()
    ↓ SCAN all syndication cache keys
    ↓ For each key, find members starting with org_uuid
    ↓ Remove matching composite keys
    ↓ Decrement metadata
  ↓ Delete membership record
```

**What gets removed:**
- All review references (composite keys) from this org
- Updated in all rating-specific caches
- Metadata decremented

### 4. Group Deleted

```php
DELETE /api/v1/reviews/syndication/groups/{uuid}

↓ SyndicationService::deleteGroup()
  ↓ Verify ownership
  ↓ SyndicationRecacheService::clearSyndicationGroupCache()
    ↓ SCAN with pattern: reviews:syndication_group:{uuid}:*
    ↓ Delete all matching keys
  ↓ Delete group (cascades to members)
```

**What gets cleared:**
- All cache keys for this syndication group
- Base keys, rating keys, metadata, by_rating keys
- Complete cleanup

## 🛠️ SyndicationRecacheService Methods

### Public Methods

#### `recacheSyndicationGroup(string $syndicationGroupUuid): void`
**When to use:** Full recache of entire group
**Use cases:**
- Manual recache via artisan command
- After data corruption
- After bulk imports

**Process:**
1. Clear all existing cache for group
2. Get all member org UUIDs
3. Query all approved reviews with SKUs
4. Group by SKU for batch processing
5. Rebuild cache completely

#### `recacheOrganizationReviews(string $syndicationGroupUuid, string $orgUuid): void`
**When to use:** Add one org's reviews to group
**Use cases:**
- Group created (owner's reviews)
- Organization joins group

**Process:**
1. Query approved reviews with SKUs from this org only
2. Group by SKU
3. Add to existing cache (incremental)
4. Update metadata

#### `removeOrganizationFromCache(string $syndicationGroupUuid, string $orgUuid): void`
**When to use:** Remove one org's reviews from group
**Use cases:**
- Organization leaves group

**Process:**
1. SCAN all syndication cache keys
2. Find composite keys starting with org_uuid
3. Remove matching members
4. Update metadata

#### `clearSyndicationGroupCache(string $syndicationGroupUuid): void`
**When to use:** Delete all cache for a group
**Use cases:**
- Group deleted
- Need fresh start

**Process:**
1. SCAN with pattern matching
2. Delete all keys in batches
3. Complete cleanup

## 🚀 Performance Optimization

### Batch Processing by SKU

Instead of processing reviews one-by-one:

```php
// ❌ Inefficient (one query per review)
foreach ($reviews as $review) {
    $product = Product::find($review->product_uuid);
    cache($product->sku, $review);
}

// ✅ Efficient (one query, grouped)
$reviewsBySku = DB::table('reviews')
    ->join('products', ...)
    ->groupBy('sku')
    ->get();

foreach ($reviewsBySku as $sku => $reviews) {
    Redis::pipeline(function ($pipe) use ($reviews) {
        // Batch operations
    });
}
```

### Redis SCAN vs KEYS

```php
// ❌ Blocks Redis
$keys = Redis::keys("reviews:syndication_group:{$uuid}:*");
Redis::del($keys);

// ✅ Non-blocking
$cursor = 0;
do {
    [$cursor, $keys] = Redis::scan($cursor, 'MATCH', $pattern, 'COUNT', 100);
    if ($keys) Redis::del($keys);
} while ($cursor != 0);
```

### Incremental Updates

```php
// When org joins
// ✅ Only cache new org's reviews
recacheOrganizationReviews($groupUuid, $newOrgUuid);

// ❌ Don't recache everything
// recacheSyndicationGroup($groupUuid); // Wasteful!
```

## 📊 Example Scenarios

### Scenario 1: Create Group

**Action:** Store A creates "Fashion Brands" group

**Database:**
```sql
INSERT INTO syndication_groups (uuid, name, owner_org_uuid)
VALUES ('GROUP-123', 'Fashion Brands', 'ORG-A');

INSERT INTO syndication_group_members (syndication_group_uuid, org_uuid)
VALUES ('GROUP-123', 'ORG-A');
```

**Cache Operations:**
```sql
-- Store A has 50 reviews for SKU "TSHIRT-BLUE-M"
SELECT * FROM reviews
WHERE org_uuid = 'ORG-A'
  AND status = 'approved'
  AND product_uuid IN (SELECT uuid FROM products WHERE sku = 'TSHIRT-BLUE-M');
-- Returns 50 reviews
```

```redis
# Cache all 50 reviews
ZADD reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M
  1734567890 "ORG-A:review-1"
  1734567891 "ORG-A:review-2"
  ...
  1734567940 "ORG-A:review-50"

# Update metadata
HMSET reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M:meta_data
  total_reviews 50
  total_rating 225
  star_5 30
  star_4 15
  star_3 5
```

**Result:** Group created with 50 reviews cached ✅

### Scenario 2: Store B Joins

**Action:** Store B joins with token

**Database:**
```sql
INSERT INTO syndication_group_members (syndication_group_uuid, org_uuid)
VALUES ('GROUP-123', 'ORG-B');
```

**Cache Operations:**
```sql
-- Store B has 30 reviews for same SKU
SELECT * FROM reviews
WHERE org_uuid = 'ORG-B'
  AND status = 'approved'
  AND product_uuid IN (SELECT uuid FROM products WHERE sku = 'TSHIRT-BLUE-M');
-- Returns 30 reviews
```

```redis
# Add Store B's reviews to existing cache
ZADD reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M
  1734567950 "ORG-B:review-51"
  1734567951 "ORG-B:review-52"
  ...
  1734567980 "ORG-B:review-80"

# Update metadata (increment)
HINCRBY reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M:meta_data total_reviews 30
HINCRBY reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M:meta_data total_rating 135
HINCRBY reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M:meta_data star_5 20
```

**Result:** Now 80 total reviews (50 + 30) ✅

### Scenario 3: Store B Leaves

**Action:** Store B leaves the group

**Cache Operations:**
```redis
# Find all keys
SCAN 0 MATCH "reviews:syndication_group:GROUP-123:*" COUNT 100

# For each key, remove ORG-B members
ZREM reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M
  "ORG-B:review-51"
  "ORG-B:review-52"
  ...
  "ORG-B:review-80"

# Update metadata (decrement)
HINCRBY reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M:meta_data total_reviews -30
HINCRBY reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M:meta_data total_rating -135
```

**Result:** Back to 50 reviews (only Store A) ✅

## 🎯 Manual Recaching

### Artisan Command

```bash
# Recache entire syndication group
php artisan syndication:recache {group_uuid}
```

**When to use:**
- After bulk review imports
- After data migration
- Cache corruption recovery
- Testing

**Example:**
```bash
php artisan syndication:recache GROUP-123

# Output:
# Recaching syndication group: GROUP-123
# ✓ Successfully recached syndication group
```

### Programmatic Access

```php
use App\Services\Reviews\SyndicationRecacheService;

$recacheService = app(SyndicationRecacheService::class);

// Full group recache
$recacheService->recacheSyndicationGroup('GROUP-123');

// Add one org
$recacheService->recacheOrganizationReviews('GROUP-123', 'ORG-C');

// Remove one org
$recacheService->removeOrganizationFromCache('GROUP-123', 'ORG-B');

// Clear all
$recacheService->clearSyndicationGroupCache('GROUP-123');
```

## 🐛 Troubleshooting

### Reviews not appearing after joining

**Check:**
```bash
# 1. Verify membership
SELECT * FROM syndication_group_members WHERE org_uuid = 'ORG-B';

# 2. Check if products have SKUs
SELECT uuid, sku FROM products WHERE org_uuid = 'ORG-B' AND sku IS NOT NULL;

# 3. Verify reviews are approved
SELECT COUNT(*) FROM reviews WHERE org_uuid = 'ORG-B' AND status = 'approved';

# 4. Check cache
redis-cli
> ZRANGE reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M 0 -1
```

**Fix:**
```bash
php artisan syndication:recache GROUP-123
```

### Reviews still showing after leaving

**Check:**
```redis
# Find rogue entries
ZRANGE reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M 0 -1
# Look for ORG-B:* members
```

**Fix:**
```php
$recacheService->removeOrganizationFromCache('GROUP-123', 'ORG-B');
```

### Metadata counts are wrong

**Check:**
```redis
HGETALL reviews:syndication_group:GROUP-123:product_group:TSHIRT-BLUE-M:meta_data
```

**Fix:**
```bash
# Full recache recalculates metadata
php artisan syndication:recache GROUP-123
```

## 📝 Best Practices

### ✅ Do

- Let automatic recaching handle group operations
- Use manual recache after bulk operations
- Monitor Redis memory usage
- Log recaching operations

### ❌ Don't

- Don't manually manipulate syndication cache
- Don't skip recaching when membership changes
- Don't use KEYS command (use SCAN)
- Don't recache entire group when only one org changes

## 🎉 Summary

The recaching system provides:

✅ **Automatic** - No manual intervention needed
✅ **Efficient** - Batch processing by SKU
✅ **Incremental** - Only update what changed
✅ **Safe** - Uses SCAN instead of KEYS
✅ **Manual override** - Artisan command available
✅ **Comprehensive** - Handles all membership changes

**Result:** Syndication cache stays in sync automatically! 🚀

---

**Implementation Date:** December 19, 2025
**Status:** ✅ Complete and Production-Ready

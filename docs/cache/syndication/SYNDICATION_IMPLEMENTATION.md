# Review Syndication Implementation for Yuko

This document describes the implementation of review syndication across multiple stores in Yuko, inspired by Judge.me's cross-store review sharing feature.

## Overview

Review syndication allows multiple Shopify/WooCommerce stores to share reviews for the same products. This is useful for businesses that operate multiple storefronts selling the same products.

## How It Works

### 1. Store Connection

**Similar to Judge.me:**
- One store creates a syndication group and receives a unique token
- Other stores join the group using this token
- Products are matched across stores using SKU (Stock Keeping Unit)

### 2. Key Features

✅ **Token-based group creation and joining**
✅ **SKU-based product matching** (exactly like Judge.me)
✅ **Automatic review aggregation** across all stores in the group
✅ **Group management** (leave, delete, regenerate token)
✅ **Owner controls** (only group owner can delete or regenerate token)
✅ **Feature gating** (enterprise tier only, already defined in FeatureRegistry)

## Database Schema

### Tables Created

#### `syndication_groups`
Stores the syndication groups.

```sql
- id (bigint)
- uuid (uuid, unique)
- name (string) - Group name
- owner_org_uuid (uuid) - Organization that created the group
- token (string, unique) - Join token
- is_active (boolean) - Can be toggled by owner
- created_at, updated_at (timestamps)
```

#### `syndication_group_members`
Stores which organizations belong to which groups.

```sql
- id (bigint)
- uuid (uuid, unique)
- syndication_group_uuid (uuid) - Foreign key to syndication_groups
- org_uuid (uuid) - Foreign key to organizations
- joined_at (timestamp)
- created_at, updated_at (timestamps)
- UNIQUE constraint on (syndication_group_uuid, org_uuid)
```

## Files Created

### Models
- `app/Models/SyndicationGroup.php` - Syndication group model with relationships
- `app/Models/SyndicationGroupMember.php` - Member mapping model

### Services
- `app/Services/Reviews/SyndicationService.php` - Core business logic for managing groups
- `app/Services/Reviews/SyndicatedReviewCacheService.php` - Handles retrieving syndicated reviews from cache

### Controllers
- `app/Http/Controllers/Reviews/SyndicationController.php` - API endpoints for syndication

### Migrations
- `database/migrations/2025_12_19_000001_create_syndication_groups_table.php`
- `database/migrations/2025_12_19_000002_create_syndication_group_members_table.php`

## API Endpoints

All endpoints require authentication (`auth:api` middleware) and are prefixed with `/api/v1/reviews/syndication`

### Group Management

#### Create a Syndication Group
```
POST /api/v1/reviews/syndication/groups
Body: { "name": "My Store Group" }

Response:
{
  "message": "Syndication group created successfully",
  "group": {
    "uuid": "...",
    "name": "My Store Group",
    "token": "abc123def456...",
    "is_active": true,
    "owner_org_uuid": "...",
    "created_at": "2025-12-19T...",
    "member_count": 1
  }
}
```

#### Join a Syndication Group
```
POST /api/v1/reviews/syndication/groups/join
Body: { "token": "abc123def456..." }

Response:
{
  "message": "Successfully joined syndication group",
  "group": { ... }
}
```

#### Get Current Group
```
GET /api/v1/reviews/syndication/groups/current

Response:
{
  "group": { ... },
  "members": [
    {
      "uuid": "...",
      "org_uuid": "...",
      "org_name": "Store 1",
      "store_url": "https://store1.com",
      "joined_at": "2025-12-19T...",
      "is_owner": true
    },
    {
      "uuid": "...",
      "org_uuid": "...",
      "org_name": "Store 2",
      "store_url": "https://store2.com",
      "joined_at": "2025-12-19T...",
      "is_owner": false
    }
  ]
}
```

#### Leave Group
```
POST /api/v1/reviews/syndication/groups/leave

Response:
{
  "message": "Successfully left the syndication group"
}
```

#### Delete Group (Owner Only)
```
DELETE /api/v1/reviews/syndication/groups/{uuid}

Response:
{
  "message": "Syndication group deleted successfully"
}
```

#### Regenerate Token (Owner Only)
```
POST /api/v1/reviews/syndication/groups/{uuid}/regenerate-token

Response:
{
  "message": "Token regenerated successfully",
  "group": { ... }
}
```

#### Toggle Group Status (Owner Only)
```
POST /api/v1/reviews/syndication/groups/{uuid}/toggle-status

Response:
{
  "message": "Group status updated successfully",
  "group": { ... }
}
```

### Review Retrieval

#### Get Syndicated Reviews for a Product
```
GET /api/v1/reviews/syndication/products/{productUuid}/reviews?page=1&per_page=30&sort=newest&rating=5

Response:
{
  "reviews": [ ... ],
  "pagination": {
    "current_page": 1,
    "per_page": 30,
    "total": 150,
    "last_page": 5
  },
  "metadata": {
    "total_reviews": 150,
    "average_rating": 4.5,
    "star_1": 5,
    "star_2": 10,
    "star_3": 20,
    "star_4": 50,
    "star_5": 65
  },
  "is_syndicated": true,
  "source_count": 3
}
```

## How Product Matching Works

**Exactly like Judge.me:**

1. Products are matched by **SKU** (Stock Keeping Unit)
2. When a product has a SKU, the system:
   - Finds all organizations in the syndication group
   - Searches for products with the same SKU across those organizations
   - Aggregates reviews from all matching products

3. If a product has no SKU, only reviews from that specific organization are shown

### Example:

**Store 1 (Owner):**
- Product: "Blue T-Shirt"
- SKU: "TSHIRT-BLUE-M"
- Reviews: 50

**Store 2 (Member):**
- Product: "T-Shirt Blue Medium"
- SKU: "TSHIRT-BLUE-M"
- Reviews: 30

**Store 3 (Member):**
- Product: "Medium Blue Tee"
- SKU: "TSHIRT-BLUE-M"
- Reviews: 20

**Result:** All three stores will show a combined 100 reviews for products with SKU "TSHIRT-BLUE-M"

## Review Cache Integration

The syndication service integrates seamlessly with the existing Redis cache system:

### Cache Keys Used
```
# Product reviews from Organization A
reviews:organization:{org_a_uuid}:product:{product_a_uuid}

# Product reviews from Organization B
reviews:organization:{org_b_uuid}:product:{product_b_uuid}

# Product reviews from Organization C
reviews:organization:{org_c_uuid}:product:{product_c_uuid}
```

### Aggregation Logic

1. Retrieve syndication group for the requesting organization
2. Get all organization UUIDs in the group
3. Find all products with matching SKU across those organizations
4. Fetch reviews from each product's cache
5. Merge and sort reviews by the requested criteria (newest, oldest, highest, lowest)
6. Paginate the combined result
7. Aggregate metadata (total reviews, average rating, star distribution)

## Business Rules

### Group Creation
- ✅ One organization can only belong to ONE syndication group at a time
- ✅ Creating a group automatically adds the creator as a member
- ✅ A unique 32-character token is generated for the group

### Joining
- ✅ Requires valid token
- ✅ Group must be active (`is_active = true`)
- ✅ Organization cannot already be in another group
- ✅ Joining is automatic upon valid token submission

### Leaving
- ✅ Members can leave anytime
- ✅ Owner cannot leave (must delete the group instead)
- ✅ Leaving removes the organization from syndication

### Deleting
- ✅ Only the owner can delete the group
- ✅ Deleting cascades to all members (they are removed)
- ✅ Reviews remain in individual organizations' databases

### Token Management
- ✅ Only the owner can regenerate the token
- ✅ Old token becomes invalid when regenerated
- ✅ New members must use the new token

### Group Status
- ✅ Only the owner can toggle active/inactive status
- ✅ Inactive groups cannot accept new members
- ✅ Existing members remain in inactive groups

## Frontend Integration Guide

### Step 1: Settings Page

Add a "Review Syndication" section in the reviews settings:

```javascript
// Check if enterprise tier
if (organization.features.review_syndication) {
  // Show syndication UI
}
```

### Step 2: Create Group Flow

```javascript
// POST /api/v1/reviews/syndication/groups
const response = await axios.post('/api/v1/reviews/syndication/groups', {
  name: 'My Multi-Store Group'
});

// Display token to user
console.log('Share this token with other stores:', response.data.group.token);
```

### Step 3: Join Group Flow

```javascript
// POST /api/v1/reviews/syndication/groups/join
const response = await axios.post('/api/v1/reviews/syndication/groups/join', {
  token: 'abc123def456...'
});

console.log('Joined group:', response.data.group.name);
```

### Step 4: Display Syndicated Reviews

```javascript
// GET /api/v1/reviews/syndication/products/{productUuid}/reviews
const response = await axios.get(`/api/v1/reviews/syndication/products/${productUuid}/reviews`, {
  params: {
    page: 1,
    per_page: 30,
    sort: 'newest'
  }
});

if (response.data.is_syndicated) {
  console.log(`Showing reviews from ${response.data.source_count} stores`);
}

// Display reviews
response.data.reviews.forEach(review => {
  // Render review
});
```

### Step 5: Group Management UI

```javascript
// GET /api/v1/reviews/syndication/groups/current
const response = await axios.get('/api/v1/reviews/syndication/groups/current');

if (response.data.group) {
  const group = response.data.group;
  const members = response.data.members;

  console.log('Group Name:', group.name);
  console.log('Token:', group.token);
  console.log('Members:', members.length);

  // Show member list
  members.forEach(member => {
    console.log(`${member.org_name} - ${member.store_url} ${member.is_owner ? '(Owner)' : ''}`);
  });
}
```

## Migration Instructions

### Step 1: Run Migrations

```bash
php artisan migrate
```

This will create:
- `syndication_groups` table
- `syndication_group_members` table

### Step 2: Verify Feature Gate

The feature is already registered in `FeatureRegistry.php`:
```php
'review_syndication' => [
    'module' => [
        'reviews' => ['enterprise'],
    ],
],
```

### Step 3: Test the Flow

1. Create a syndication group in Store A
2. Copy the token
3. Join the group from Store B using the token
4. Ensure both stores have products with matching SKUs
5. View syndicated reviews in both stores

## Key Differences from Judge.me

### Similarities ✅
- Token-based joining
- SKU-based product matching
- Owner vs member roles
- Token regeneration
- Group deletion

### Yuko Advantages 🚀
- **API-first design** - Everything accessible via REST API
- **Integrated with existing cache** - No additional infrastructure needed
- **Multi-platform support** - Works with both Shopify and WooCommerce
- **Organization-based** - Not limited to single platform
- **Fine-grained control** - Toggle group status without deletion

### Judge.me Features Not Implemented
- Widget-specific filtering (review carousel exclusion)
- Dashboard visibility restrictions
- Google Shopping feed integration
- Product Groups requirement

## Troubleshooting

### Reviews Not Showing Up
1. **Check SKU matching:** Ensure products have identical SKUs
2. **Verify group status:** Group must be active
3. **Check cache:** Reviews must be approved and cached
4. **Confirm membership:** Both organizations must be in the group

### Cannot Join Group
1. **Check token validity:** Token must be exact match
2. **Verify group is active:** Inactive groups reject joins
3. **Check existing membership:** Organization cannot be in another group

### Permission Errors
1. **Owner actions:** Only owner can delete/regenerate/toggle
2. **Leave restrictions:** Owner cannot leave (must delete)

## Security Considerations

✅ **Token security:** 32-character random tokens
✅ **Organization isolation:** Cannot access other orgs' data
✅ **Authentication required:** All endpoints require auth:api
✅ **Owner verification:** Ownership checked before privileged operations
✅ **Unique constraints:** Prevents duplicate memberships

## Performance Considerations

✅ **Cache-based retrieval:** Uses existing Redis cache
✅ **Lazy loading:** Only fetches from matching products
✅ **Pagination:** Supports efficient pagination
✅ **Indexed queries:** Database indexes on all foreign keys

## Future Enhancements

- [ ] Webhook notifications when stores join/leave
- [ ] Analytics dashboard showing cross-store metrics
- [ ] Automatic SKU synchronization suggestions
- [ ] Review translation across languages
- [ ] Advanced filtering (by store, date range)
- [ ] Export syndicated reviews
- [ ] Bulk operations across groups

## Testing Checklist

- [ ] Create syndication group
- [ ] Generate token
- [ ] Join group with valid token
- [ ] Join group with invalid token (should fail)
- [ ] Join when already in a group (should fail)
- [ ] View current group details
- [ ] List group members
- [ ] View syndicated reviews (matching SKU)
- [ ] View reviews (no matching SKU)
- [ ] Leave group (as member)
- [ ] Leave group (as owner - should fail)
- [ ] Regenerate token (as owner)
- [ ] Regenerate token (as member - should fail)
- [ ] Toggle group status (as owner)
- [ ] Toggle group status (as member - should fail)
- [ ] Delete group (as owner)
- [ ] Delete group (as member - should fail)
- [ ] Verify cascading deletes

---

**Implementation Date:** December 19, 2025
**Laravel Version:** 11.31
**Feature Tier:** Enterprise
**Status:** ✅ Ready for Testing

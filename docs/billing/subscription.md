# Subscription Data Model Design

This document describes the subscription data model for supporting both **direct organizations** and **agencies** (which manage multiple organizations).

---

## 1. Background

- ~90% of customers are **direct organizations**.
- ~10% of customers are **agencies**, who need a single subscription applied to multiple organizations.
- We want to avoid duplicating subscription data across many organizations while keeping the majority path simple.

---

## 2. Proposed Hybrid Polymorphic Model

### Table: `billing_subscriptions`

```sql
billing_subscriptions (
    uuid UUID PRIMARY KEY,
    subscriber_type VARCHAR NOT NULL, -- 'Organization' or 'Agency'
    subscriber_uuid UUID NOT NULL,    -- org_uuid or agency_uuid
    plan_uuid UUID NOT NULL,
    status VARCHAR NOT NULL,
    billing_cycle_start BIGINT NOT NULL,
    billing_cycle_end BIGINT,
    ...
)

An Agency (subscriber_type = Agency, or
An Organization (subscriber_type = Organization)
A subscription belongs to either:

```

### Table: `agencies`

````sql
agencies (
    uuid UUID PRIMARY KEY,
    name VARCHAR,
    owner_uuid UUID, -- user that manages the agency
    ...
) ```

### Table: `agency_organizations`

```sql
agency_organizations (
    id BIGSERIAL PRIMARY KEY,
    agency_uuid UUID REFERENCES agencies(uuid),
    org_uuid UUID REFERENCES organizations(uuid),
    UNIQUE (org_uuid)
)```




````

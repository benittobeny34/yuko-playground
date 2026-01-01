# 🚀 Git Workflow Guide (Selective Release Flow)

This document describes our Git branching, merging, and release strategy.  
We use **release branches as staging**, so only approved features/fixes go into QA and production.

---

## 🔹 Branch Structure

- **`main`** → Development branch. All PRs merge here (linear history).
- **`release-*`** → Release branches (e.g. `release-20-08-2020`). Deployed to **staging/QA**.
- **`production`** → Live branch. Only fast-forward merges from release branches.

---

## 🔹 Workflow Overview

### 1. Feature Development

- Create a feature branch from `main`:
    ```bash
    git checkout -b feature/awesome-feature main
    ```

Once the Branch is Created, never sync with main again by doing rebase or merge

Commit changes and push to remote.

Open a PR into main.

✅ Rule: Use Squash and Merge → 1 commit per feature.
Keeps main history linear and clean.

2. Create a Release Branch

When preparing a release, cut the branch from the latest production state (not main):

git checkout -b release-20-08-2020 production
git push origin release-20-08-2020

✅ This ensures the release starts from what’s currently live.

3. Merge Approved Features Into the Release

Select only the features/fixes that are ready for release.

git checkout release-20-08-2020

Option 1: Cherry-Pick Commits
git cherry-pick -x <M1-hash>
git cherry-pick -x <M2-hash>
git cherry-pick -x <MN-hash>

Option 2:

Always use --no-ff so we preserve merge history.
git merge --no-ff origin/feature-a
git merge --no-ff origin/fix-b
git merge --no-ff origin/feature-c

git push origin release-20-08-2020

✅ Each merge commit = “this feature/fix was included in this release.”

4. QA & Bug Fixes on the Release Branch

Deploy the release-\* branch to staging/QA.

QA verifies only the features merged into this release.

# Example bug fix

if bugs were found during QA, fix them directly from release/production branch:
git checkout fix-20-08-2020
git commit -m "Fix API timeout in feature-a"
git push origin release-20-08-2020

Best Practice: Always back-merge release → main

After the release goes live:

# Merge release back into main to sync hotfixes

git checkout main
git merge release-20-08-2020
git push origin main

This ensures:

main contains everything that was released.

Future features are built on top of the true production code.

5. Deploy to Production

Once release is approved:

git checkout production
git merge --ff-only release-20-08-2020
git push origin production

✅ Production history stays linear.
Every production deployment is a fast-forward from a release branch.

6. Tag the Release

Always tag releases for traceability:

git tag -a v2020.08.20 -m "Release 20-08-2020"
git push origin v2020.08.20

🔹 History Styles
Linear History (on main & production)
A → B → C → D → E

Clean, easy to read.

Each PR = 1 commit (squash merge).

Used for: main, production.

Merge History (on release-\*)
A --- M1 (merge feature-a)
\
B → C (feature-a)

Preserves which features/fixes were merged.

Used for: release branches.

🔹 Git Log Tips

See history graph:

git log --oneline --graph --decorate --all

Show only merges:

git log --merges --oneline --graph

🔹 Quick Cheat Sheet

# 1. Start a feature

git checkout -b feature/awesome-feature main

# 2. Cut a release branch from production

git checkout -b release-YY-MM-DD production
git push origin release-YY-MM-DD

# 3. Merge approved features into release

git checkout release-YY-MM-DD
git merge --no-ff origin/feature-x
git merge --no-ff origin/fix-y
git push origin release-YY-MM-DD

# 4. QA tests release branch (staging = release branch)

# 5. Fix bugs directly in release branch

git commit -m "Fix bug"
git push origin release-YY-MM-DD

# 6. Deploy release to production

git checkout production
git merge --ff-only release-YY-MM-DD
git push origin production

# 7. Tag the release

git tag -a vYYYY.MM.DD -m "Release YYYY-MM-DD"
git push origin vYYYY.MM.DD

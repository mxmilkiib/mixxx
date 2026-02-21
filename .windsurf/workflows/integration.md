---
description: Mixxx Integration Branch Workflow
---

# Mixxx Integration Branch Workflow

See `INTEGRATION.md` (gist: https://gist.github.com/mxmilkiib/5fb35c401736efed47ad7d78268c80b6) for all rules, hygiene requirements, and branch status.

## Steps

### 1. Update Branches

```bash
 ./update-branches.sh
```

### 2. Merge to Integration

```bash
 git checkout integration
 git fetch upstream
 git merge upstream/main
```

### 3. Merge Feature Branches

Merge each `[x]` branch from INTEGRATION.md with "Next: Merge to integration":

```bash
 git merge origin/<branch-name>
```

### 4. Resolve Conflicts

- Schema revisions: increment version numbers
- Enum IDs in `trackmodel.h`: assign unique IDs
- Header declarations vs implementations: keep both sides

### 5. Update INTEGRATION.md

- Change `[ ]` to `[x]` for merged branches
- Update "Rebased" and "Updated" dates
- Update summary counts and "Last updated" date

```bash
 git add INTEGRATION.md && git commit -m "integration: ..."
 gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md /home/milkii/src/mixxx/INTEGRATION.md
```

### 6. Build and Verify

Incremental rebuild:

```bash
 cmake --build /home/milkii/src/mixxx/build --target mixxx -- -j$(nproc --ignore=2)
```

Full reconfigure (new CMakeLists changes or new source files):

```bash
 cmake -B /home/milkii/src/mixxx/build -S /home/milkii/src/mixxx -DCMAKE_BUILD_TYPE=RelWithDebInfo
 cmake --build /home/milkii/src/mixxx/build --target mixxx -- -j$(nproc --ignore=2)
```

### 7. Sync Gist

```bash
 gh gist edit 5fb35c401736efed47ad7d78268c80b6 --filename INTEGRATION.md /home/milkii/src/mixxx/INTEGRATION.md
```

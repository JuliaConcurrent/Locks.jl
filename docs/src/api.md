# API overview

```@eval
using DocumentationOverview
using Locks
DocumentationOverview.table_md(
    Locks;
    signature = :strip_namespace,
    include = api -> api.hasdoc && !(api.value isa Module),
)
```

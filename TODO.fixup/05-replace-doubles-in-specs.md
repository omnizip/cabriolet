# TODO 05: Replace double() in specs with real instances

## Priority: P0 (explicit rule violation)

## Problem
Specs use `double()` and `instance_double` to create mock objects that bypass
real type checking. This violates: "NEVER use `double()` in specs. No exceptions.
Use real model instances... Use lightweight structs for plain data."

Note: `instance_double` is borderline — it verifies against the real class's
interface. But the rule says "NEVER use `double()`" and the spirit is to test
real behavior. `instance_double` of internal classes that change frequently is
still fragile coupling. Replace where practical with real instances.

## Affected Files

### spec/plugin_spec.rb
- `:52` — `manager = double("manager")`
**Fix**: Use a real `PluginManager` instance or a Struct stub for the manager
interface.

### spec/models/folder_spec.rb
- `:141` — `folder.merge_prev = double("previous_folder")`
- `:157` — `folder.merge_next = double("next_folder")`
**Fix**: Use real `Models::Folder` instances.

### spec/models/cabinet_spec.rb
- `:135` — `cabinet.files = [double("file1"), double("file2"), double("file3")]`
- `:146` — `cabinet.folders = [double("folder1"), double("folder2")]`
**Fix**: Use real `Models::File` and `Models::Folder` instances.

### spec/models/file_spec.rb
- `:311` — `folder = double("folder")`
**Fix**: Use real `Models::Folder` instance.

### spec/algorithm_factory_spec.rb (instance_double — lighter touch)
- `:174-175, :428-429, :440-441` — `instance_double(Cabriolet::System::MemoryHandle)`
**Fix**: Use real `System::MemoryHandle` instances where the test doesn't depend
on specific method call verification. `MemoryHandle.new("", Constants::MODE_WRITE)`
is cheap to construct.

## Solution
Replace each `double()` / `instance_double` with a real model instance or a
`Struct.new(...)` for plain data. The test should verify behavior through real
objects.

## Verification
- `grep -rn "double(" spec/` returns 0 (or only in clearly justified edge cases)
- All specs pass

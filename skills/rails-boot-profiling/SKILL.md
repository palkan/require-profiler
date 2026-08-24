---
name: rails-boot-profiling
description: Profile Rails application boot time to find slow requires and initializers. Use when the user asks why the app boots slowly, wants to profile boot time, or needs to optimize require/load performance.
gem: require-profiler
versions: ">= 0.3"
---

# Rails Boot Time Profiling

Profile Rails application boot time using the require-profiler gem. This skill helps identify which `require`, `load`, YAML, HTTP, and Rails initialization steps dominate startup time, and provides tools to drill deeper into slow files.

## Prerequisites

Before profiling, ensure these conditions are met:

1. The `require-profiler` gem is in the Gemfile (at minimum in the development group).

2. Pick the boot to measure with `config.eager_load` in the target environment config: keep it `false` to profile the development boot (lazily-loaded application code stays out of the profile), or set it to `true` to profile a production-like boot (all application code loads and shows up). Default to the development boot unless the user asks about production or CI.

3. Add `-W0` to the Ruby command to suppress warnings and keep output clean.

4. If the app uses Spring, disable it while profiling (`DISABLE_SPRING=1`). Otherwise you measure a fork of a preloaded process instead of a real boot.

## Step 1: Run a Full Boot Profile

Run the base profiling command:

```sh
bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

This loads `config/boot.rb` first (to set up Bundler and Bootsnap) and then profiles everything loaded by `config/environment.rb`.

The output is an indented tree showing each required file with its load time (self + children) in milliseconds:

```
config/environment.rb — 4312.071ms
  config/application.rb — 3672.445ms
    railties (>= 0) — 1023.112ms
      actionpack (>= 0) — 412.331ms
        actionview (>= 0) — 198.442ms
    app/models/user.rb — 87.203ms
    app/models/order.rb — 142.891ms
      app/models/concerns/auditable.rb — 12.004ms
  config/initializers/stripe.rb — 523.117ms
    stripe (>= 0) — 498.201ms
```

The profiler's own setup (require-profiler files and the sniffer gem) appears at the top of the tree. Ignore those lines.

To get a quick count of how many files were loaded:

```sh
bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb | wc -l
```

## Step 2: Narrow the Scope

### Filter by Threshold

Exclude files that loaded faster than a given number of milliseconds (supports floats):

```sh
REQUIRE_PROFILE_THRESHOLD=100 bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

This shows only files that took 100ms or more to load — useful for quickly spotting the biggest offenders.

### Filter by Focus Pattern

Show only files matching a pattern (uses `Regexp.new(...)` under the hood):

```sh
REQUIRE_PROFILE_FOCUS="stripe" bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

The focus filter also keeps ancestor nodes in the tree, so you can see the full require chain leading to the matched files.

Combine both for a precise view:

```sh
REQUIRE_PROFILE_THRESHOLD=50 REQUIRE_PROFILE_FOCUS="initializers" bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

## Step 3: Check YAML and HTTP Activity During Boot

By default, require-profiler tracks YAML file loads (`YAML.load_file`, etc.) and adds them to the profile tree. This helps find initializers or gems that parse large YAML configs at boot time.

HTTP request tracking is also available but requires the [sniffer](https://github.com/aderyabin/sniffer) gem to be in the Gemfile. HTTP entries appear as `http:`-prefixed lines (e.g., `http:GET:https://...`). This surfaces any HTTP calls made during boot (e.g., config fetches from remote services, gem activation pings).

Bootsnap caches parsed YAML and serves it back on warm boots, hiding the true parse cost. Run the profile twice: a normal run and a cold rerun with `DISABLE_BOOTSNAP=1`.

To disable either:

```sh
# Disable YAML tracking
REQUIRE_PROFILER_YAML=false bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb

# Disable HTTP tracking
REQUIRE_PROFILER_HTTP=false bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb

# Disable all plugins (YAML, HTTP, and Rails)
REQUIRE_PROFILER_PLUGINS=false bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

## Step 4: Check the Rails Initialization Lines

When Rails is loaded, the profiler also captures the Rails initialization pipeline as `rails:`-prefixed lines: `initializer:` (railtie initializers), `to_prepare:` (reload callbacks that rerun on every code reload in development), and `load_hook:` (lazy load hooks such as `ActiveSupport.on_load(:active_record)`).

On large apps, initialization often outweighs the requires themselves, so always check this part of the tree:

```sh
REQUIRE_PROFILE_FOCUS="rails:" bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

Disable with `REQUIRE_PROFILER_RAILS=false`, or set a threshold if the extra lines add too much noise.

## Step 5: Deep-Dive with Stackprof

When you identify a file that is unexpectedly slow to load, use Stackprof to profile what happens inside that file during `require`:

```sh
REQUIRE_PROFILE_STACKPROF=config/initializers/stripe.rb bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

The `stackprof` gem must be in the Gemfile. This generates two files:

- `config-initializers-stripe-stackprof.json` — JSON format, viewable in [Speedscope](https://www.speedscope.app/)
- `config-initializers-stripe-stackprof.dump` — raw Stackprof data, analyzable with the `stackprof` CLI

To analyze with the stackprof CLI:

```sh
bundle exec stackprof config-initializers-stripe-stackprof.dump
bundle exec stackprof config-initializers-stripe-stackprof.dump --method 'ClassName#method_name'
```

To view in Speedscope, open https://www.speedscope.app/ and drag the `.json` file onto the page (nothing is uploaded — parsing is local).

When reading the sampled profile, separate *total time* (a frame plus everything it calls) from *self time* (work in the frame's own body). If a frame has a huge total and near-zero self, drill into its children until self time shows up. Native frames (OpenSSL, C extension init, syscalls) never appear in the require tree. Only this step can show them.

## Step 6: Export as JSON for Speedscope

Generate a Speedscope-compatible JSON profile of the entire boot:

```sh
REQUIRE_PROFILE_PATH=tmp/require-profile.json bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

This writes a JSON file conforming to the [Speedscope file format schema](https://www.speedscope.app/file-format-schema.json). Open it in Speedscope and use the **Left Heavy** view to find the most expensive require chains, and the **Sandwich** view to find files that appear repeatedly across different chains.

If the Speedscope CLI is installed (`npm install -g speedscope`), open it directly:

```sh
npx speedscope tmp/require-profile.json
```

You can also use the `REQUIRE_PROFILE_FORMAT` env var to select the output format explicitly (`text`, `json`, or `call_stack`). When the output path ends in `.json`, the JSON format is selected automatically.

## Collapsed Call Stack Format

For flame graph generation with external tools (e.g., `flamegraph.pl`, `inferno`), use the collapsed call stack format:

```sh
REQUIRE_PROFILE_FORMAT=call_stack REQUIRE_PROFILE_PATH=tmp/require-profile.txt bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
```

This emits one line per stack in Brendan Gregg's collapsed format with per-frame self time in milliseconds.

## Environment Variable Reference

| Variable | Purpose | Example |
|---|---|---|
| `REQUIRE_PROFILE_THRESHOLD` | Minimum load time in ms to include (float) | `100`, `50.5` |
| `REQUIRE_PROFILE_FOCUS` | Regexp pattern to filter files | `"stripe"`, `"initializers"` |
| `REQUIRE_PROFILE_PATH` | Output file path (enables file output) | `tmp/require-profile.json` |
| `REQUIRE_PROFILE_FORMAT` | Output format: `text`, `json`, `call_stack` | `json` |
| `REQUIRE_PROFILE_STACKPROF` | File path to deep-profile with Stackprof | `config/initializers/stripe.rb` |
| `REQUIRE_PROFILER_YAML` | Disable YAML tracking when set to `false` | `false` |
| `REQUIRE_PROFILER_HTTP` | Disable HTTP tracking when set to `false` | `false` |
| `REQUIRE_PROFILER_RAILS` | Disable Rails initialization tracking when set to `false` | `false` |
| `REQUIRE_PROFILER_PLUGINS` | Disable all plugins when set to `false` | `false` |

## Important: Use the Profiler's Built-in Filtering

**Prefer the profiler's built-in filtering and searching capabilities over `grep`, `tail`, `head`, `awk`, or `sed` to filter or search results:**

- To find slow files → use `REQUIRE_PROFILE_THRESHOLD`, not `grep` for timing patterns
- To investigate a specific gem or file → use `REQUIRE_PROFILE_FOCUS`, not `grep` for the name
- To reduce output size → use `REQUIRE_PROFILE_THRESHOLD` + `REQUIRE_PROFILE_FOCUS`, not `tail -N | head -M`

Shell-based filtering breaks the indented tree structure (you lose parent-child relationships), misses context, and requires re-running the full profile each time you change the filter. The built-in env vars preserve the tree, show ancestor chains, and handle edge cases the profiler already knows about.

The only acceptable uses of piping are:
- `| wc -l` to count total loaded files in step 1
- Piping into a file when `REQUIRE_PROFILE_PATH` is not available

## Recommended Agent Workflow

Follow this sequence when a user asks about slow boot time:

1. **Get a baseline.** Run the full profile command prefixed with `time`, and note the wall-clock boot time and the total file count (`| wc -l`).

   ```sh
   bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
   ```

2. **Find the top offenders.** Re-run with `REQUIRE_PROFILE_THRESHOLD` to surface only slow files. Start with a threshold that shows roughly 10-20 entries (e.g., if total boot is ~4s, try 100ms; if ~1s, try 30ms). Report the top slowest entries to the user.

   ```sh
   REQUIRE_PROFILE_THRESHOLD=100 bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
   ```

3. **Investigate specific areas.** Use `REQUIRE_PROFILE_FOCUS` to zoom into a gem, initializer, or file. The focus pattern is a regexp — use it to match file paths, gem names, or directory patterns. Combine with `REQUIRE_PROFILE_THRESHOLD` for precision.

   ```sh
   # Investigate a specific gem
   REQUIRE_PROFILE_FOCUS="stripe" bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb

   # Investigate all initializers that took > 50ms
   REQUIRE_PROFILE_THRESHOLD=50 REQUIRE_PROFILE_FOCUS="initializers" bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
   ```

4. **Check for boot-time side effects.** YAML, HTTP, and Rails initialization entries appear in the profile tree by default. HTTP calls during boot are almost always worth investigating — they add latency and can fail. Use `REQUIRE_PROFILE_FOCUS` to find them:

   ```sh
   # Find YAML loading (rerun with DISABLE_BOOTSNAP=1 — the cache hides parse costs)
   REQUIRE_PROFILE_FOCUS="\.yml" bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb

   # Find HTTP calls during boot
   REQUIRE_PROFILE_FOCUS="http:" bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb

   # Find slow initializers, reload callbacks, and load hooks
   REQUIRE_PROFILE_FOCUS="rails:" bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
   ```

5. **Deep-dive when needed.** For files that are unexpectedly slow (the load time seems too high for what the file does), use `REQUIRE_PROFILE_STACKPROF` to generate a Stackprof profile and identify what's happening inside that file.

   ```sh
   REQUIRE_PROFILE_STACKPROF=config/initializers/stripe.rb bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
   ```

6. **Generate a JSON profile for handoff.** If the user wants to explore the data themselves, or if the profile is too large to analyze in text, export to JSON and point them to Speedscope.

   ```sh
   REQUIRE_PROFILE_PATH=tmp/require-profile.json bundle exec ruby -W0 -r./config/boot -require-prof config/environment.rb
   ```

7. **Suggest actionable improvements** based on findings. The common offenders:
   - Move heavy gem requires behind lazy loading or autoload (cloud SDKs, SOAP/PDF/spreadsheet/search clients, and generated API gems are rarely needed across the whole app)
   - Move CLI and dev-only tooling gems to the right Gemfile group (or `require: false`), and scope process-specific boot files (background consumers, admin UIs) to the processes that need them
   - Make initializer and `to_prepare` work lazy, resolved on first use and memoized (`to_prepare` also reruns on every dev reload)
   - Keep routes lazy and drawn once. Rails 8 defers drawing to the first request, and older apps can use the `routes_lazy_routes` gem. Watch for gems forcing redraws (for example, set Devise's `config.reload_routes = false`)
   - Adopt new framework defaults (`config.load_defaults`, etc.) and keep gems updated, since newer versions regularly ship boot speedups
   - Defer anything touching I18n until it is configured (early lookups, locale registrations, class-level validation messages)
   - Delay heavy class-level work in app code or cache what it builds (big DSLs, for example GraphQL schemas, Grape, Active Admin)
   - Replace boot-time HTTP calls with cached configs or async fetches
   - Enable `bootsnap` and keep it updated (if you build production images, mind the cache precompilation)

   Verify each fix with a cheap focused run (`REQUIRE_PROFILE_FOCUS` on the touched area). Rerun the full baseline once after a batch of fixes to confirm the total win. Mind where each win lands, since some fixes speed up development only, and lazy loading moves work from boot to first use (on a production hot path that can grow the tail latency).

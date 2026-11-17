# Common settings guide

[简体中文](settings.md) · [English](settings.en.md)

2026-11-13

<a id="start"></a>

## Where to start

Checked against the 0.6.0 development build. Released builds may use different labels or options. Server administrators manage instance settings. Adjust personal appearance and reading preferences through the options available on the current client and page. Complete [installation](https://scrapefun.com/?lang=en#/docs/linux), connect storage, create a library, and run an initial scan.

Keep connection passwords, API keys, private addresses, and complete backups private. Share only necessary redacted fields, never an entire configuration export. See [AI connections](ai-settings.en.md) for models and [API reference](api.en.md) for programmatic access.

<a id="libraries"></a>

## Storage and libraries

| Location or field | Purpose and input | Verify after saving |
| --- | --- | --- |
| Storage Sources | Add a storage type supported by the UI, with its address and credentials | Browse a few real files from Server |
| Library name and type | Choose a recognizable name and the correct movie, TV, comic, or book type | Confirm the type matches the content |
| Media directory | A directory visible to Server; Docker uses a mounted container path | Check that files exist and required read access is available |
| Scraper | An active source supporting the library type and required capabilities | Check search and details for one work |
| Metadata and image languages | Ordered preferences supported by the source | Check titles, summaries, and artwork |

Scan a small directory before expanding. Virtual libraries depend on discovery, imports, or comic chapter methods; filesystem scanning is not a substitute. Comic metadata alone does not imply online reading. Investigate task errors and storage access before deleting a library to address a single failure.

<a id="scraping"></a>

## Scraping and matching

Scraping & Matching contains identification, filename cleaning, and metadata translation. Noise terms remove irrelevant resource labels while preserving titles, years, and season/episode numbers. Check [cleaning tests](scraper-api.en.md#cleaning) before binding a rule to a source.

For incorrect matches, check library type, source, and filename first, then candidate title, year, and ID. Matching threshold, lead margin, and search variants affect candidate selection and request volume. Keep defaults initially, change one option at a time, and compare the same sample set. Lowering a threshold does not fix incorrect provider data.

Configure automatic translation, scope, and prompts in the same area after binding an enabled [text AI connection](ai-settings.en.md#translation). See the [developer reference](scrapers.en.md) for custom scraper capabilities, authoring, and saving.

<a id="reading"></a>

## Reading and default applications

| Setting | Scope |
| --- | --- |
| Appearance & home | Available appearance and home options; check the current client's result after saving |
| Files → Open with… | Select an installed application that can handle the supported resource type |
| Comic reader | Adjust reading direction, touch zones, backgrounds, and image enhancement. Configure parallel image loading under Advanced settings → Reading loading |
| Book reader | Adjust typography, layout, theme, and PDF display |
| Third-Party Integrations | Manage text AI, voice AI, and danmaku sources |

Reader changes become defaults on the current device for the same server and account. Saved preferences for individual titles take precedence. For remote narration, test short text and confirm voice and cost before prolonged use.

<a id="tasks-access"></a>

## Automation, tasks, and access

Scans & Background Tasks manages scheduled tasks supported by your instance. Run once manually to verify directories, sources, and permissions before scheduling. Avoid overlapping scans of the same library. Follow task status and errors, using pause, cancel, or retry only when the UI offers them.

Users & Devices manages users, library access, and connected devices. Grant regular users only the libraries they need, then verify access as that user. Revoking or removing a device can interrupt its session; confirm the target first. Do not attach device credentials or complete user lists to public reports.

For AI automation, specify permitted libraries and writes. Queries, scans, metadata updates, and deletions have different effects. Having permission does not mean the user requested every possible action. See [scanning and tracking](api.en.md#tasks) for task APIs.

<a id="maintenance"></a>

## Caches, connections, and maintenance

Cache management shows usage, capacity, and cleanup options available in the instance. Confirm whether an action affects cached or original data and follow the UI's scope. Cleared content may need regeneration or downloading. A cache directory is not a complete backup.

Configure the network proxy in Services & connections when network access requires it. Use your own proxy address and credentials, test the connection, then verify the intended source. A proxy change does not guarantee every client and resource uses it. Keep proxy passwords out of public URLs and logs.

Export or restore backups under **Backup & Maintenance → Backup & Restore**. Server logs, restarts, and resets are also under **Backup & Maintenance**. Manage your ScrapeFun account connection and license under **License & Updates → Server License**. Check for and install updates under **License & Updates → Server Updates**. Back up before upgrading or restoring. Restarting interrupts connections and background work. Follow the scope shown for restore and reset operations. For connection failures, start by checking the connection status and settings. See [data, backups, and recovery](https://scrapefun.com/?lang=en#/docs/data) and [updates and maintenance](https://scrapefun.com/?lang=en#/docs/updates).

Advanced settings tunes supported hardware and processing parameters. Keep defaults without a reproducible issue. Record original values and check latency, resource usage, and actual results after changes. Share only necessary redacted error information.

# Teacher notes

Flutter and Laravel connect independently to the same Supabase database. This activity opens without login and uses fictional classroom records only. Refresh each app to see changes made in the other.

The demo migration gives the anonymous API role student CRUD and search access. Anyone with the public project settings can read or change those records, including through direct requests. A private Codespaces port does not protect the database API. Obtain the owner's approval before enabling it. Use an isolated practice project, never real student information.

Laravel validation does not process Flutter requests. The migration adds shared database validation and timestamps, while Flutter checks forms for helpful messages. RLS stays enabled. Other application tables are not opened by this migration.

Before class, confirm Laravel works, check Codespaces availability, and give students STUDENT_GUIDE.md and CODE_REFERENCE.md. Each student should use their own Supabase project unless you arrange a shared fictional directory. No Supabase Auth accounts are required. Never distribute database passwords or secret/service-role keys.

Check that students can open private port 8080, create a record in Flutter, compare it with Laravel and Supabase, edit from both interfaces, search, trigger validation and duplicate errors, cancel deletion, and delete a disposable record. Run analysis, all eight supplied tests, and a web build.

Tests use an in-memory repository and do not prove live persistence. Grade live database evidence separately. Ask for both repository links, matching record screenshots, passing checks, and a brief explanation of each main file.

If a policy or function already exists, inspect migration history. Do not use migrate:fresh to repair the database. Read VERIFICATION.md for actual instructor results. Account limits, network issues, and configuration differences can still cause errors even when students follow the guide.

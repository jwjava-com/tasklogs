# tasklogs

A set of scripts written over a decade ago to help create weekly timesheets.
They were tweaked here-and-there during brief periods of down-time for a few years.
They still appear to work.  Putting here as they might be useful to someone.

Looking at these again, after several years, there's several things that could have
been done differently.  Handling of paths, for instance, and extracting some code
to a PM would be good.  I've updated a few times to try to migrate from running in
a Windows Command Prompt environment, using Active Perl, to run in a bash shell in
either Cygwin or Linux.

## TODOS

- Allow configuring end of week day, currently hard-coded to Saturday
- Add "started at" time to current task file
- Add backup option to backup raw daily task log files to a directory
- Add ability to provide date/time for altering start time of tasks (vs -mins)
- Allow changing back to the previous (or previous X) task (ala bash !! or !-n)
- Allow resuming a day after a previous 'quit'
- Update fmttimearr() to use DateTime
- Update rename\_tasks() to use Tie::File
- Add better handling of incorrect command-line parameters
- Translate to other languages (русский язык)
- (started, fixed 'quit yesterday', bug in DateTime treats 'Sunday' as next week, not the day that just ended) Fix ending Sunday (week) on Monday morning
- (started, [to Java](https://github.com/jonwarren/jtasklogs)) Port to other languages
- ~~(done) Allow renaming the current task~~
- ~~(done) Fix `weekly.pl` help text to have 4-digit years~~
- ~~(done) Fix removal of current_task file on quit~~
- ~~(done) Consider sorting `.hours` file before totaling time~~
- ~~(done) `weekly.pl`: Auto-calculate Saturday date if none specified~~
- ~~(done) Extract common code to a module~~
- ~~(done) Expand documentation~~
- ~~(done) Auto-create necessary paths & allow specifying different paths~~
- ~~(done) Handle spaces inside quoted task names~~
- ~~(done) Add configurable list (or file) of tasks to be treated same as 'break'~~
- ~~(done) Handle ending a day after midnight~~
- ~~(done) Update to allow changing rounding/output~~
- ~~(done) Change end-of-day files to always store raw seconds totals, to improve week-end numbers~~
- ~~(done) Rename end-of-week files from MMDDYY to YYMMDD~~
- ~~(done) Fix prompting to edit end-of-day log file~~
- ~~(done) Add option for renaming the current task: `task.pl -r "new task"` or `task.pl --rename "new task"`~~

## Details

- [task.md](task.md)
- [daily.md](daily.md)
- [weekly.md](weekly.md)
- [tasklogs.md](tasklogs.md)


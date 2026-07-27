<!-- Filename: review.md -->
<!-- Description: Fact-check and critique of the Hermes Emacs improvement plan -->
<!-- Author: SCS -->
<!-- Copyright: Copyright (C) 2026, SCS, all rights reserved. -->
<!-- Created: 2026-07-26 Sun 19:25 -->
<!-- Version: 0.1.0 -->
<!-- Last-Updated: 2026-07-27 Mon 07:02 -->
<!-- Update #: 2 -->

# Review of the Emacs configuration improvement plan

This records the fact-check of the rejected Hermes plan formerly named
`2026-07-26_191559-emacs-config-review-and-improvements.md`. The faulty
source plan was deleted after this review established a replacement backlog.

## Verdict

**Do not use the Hermes document as an execution plan.**

Its broad instincts are reasonable: `init.el` is large, some cohesive
subsystems could move into libraries, several important helpers lack tests, and
the operator documents could be refreshed. But many of its high-severity
findings are factually wrong. Several proposed fixes use nonexistent or
irrelevant APIs, and a few would change working behavior without solving the
claimed problem.

The most serious weakness is not taste; it is verification. The document often
quotes the source inaccurately, treats normal Emacs behavior as a bug, and then
builds multi-stage work on top of those mistakes. I would discard the staged
plan and replace it with the short evidence-backed backlog near the end of this
review.

## What I checked

- Read `early-init.el`, `init.el`, the relevant `lisp/`, `bin/`, test, and Org
  files.
- Checked APIs using the installed GNU Emacs 31.0.90 docstrings and bundled
  Emacs source.
- Checked the installed `no-littering` source and README.
- Ran the three existing ERT suites together. All 24 tests passed.
- The original fact-check pass did not edit existing configuration or
  documentation files; the later implementation pass is recorded in
  `changelog.org`.

The test run did expose one useful detail that Hermes missed: Emacs warned that
`lisp/scs-cl.el` is newer than `lisp/scs-cl.elc`, but loaded the older bytecode.
A future test runner should set `load-prefer-newer` before loading project
libraries, or otherwise exclude stale untracked bytecode.

## Material errors in the plan

### 1. Named hooks do not accumulate on reload

The plan's main correctness claim is false. GNU Emacs documents `add-hook` as:
“FUNCTION is not added if already present.” The two global save hooks are named
functions:

- `scs/delete-trailing-whitespace-maybe`
- `scs/update-last-updated-on-save`

Reloading `init.el` does not add second copies of those functions. They are also
easy to disable with ordinary `remove-hook`; the absence of a prewritten
teardown command is not a correctness defect.

The proposed hook registry, `scs/reset-hooks`, symbol property named
`re-entrant`, and advice around `use-package` initialization are unnecessary.
The `re-entrant` property has no documented hook meaning. `add-function` is
also the wrong abstraction for an ordinary hook when `add-hook` and
`remove-hook` already provide the intended data model.

There is a smaller reload-maintenance concern: anonymous hook/advice functions
are harder to remove after their definitions change. The proportionate fix is
to give those few lambdas names, not clear every hook owned by the config.

### 2. The capture hook does not call `kill-emacs`

The plan says `scs/org-capture-finalize-hook` calls `kill-emacs`. It does not.
At `init.el:185-189` it calls `delete-frame`, only when more than one frame
exists and the selected frame is an Emacs client frame.

There is still a real policy question: any extra client frame used for an
interactive capture can be deleted, even if it was not created specifically
for a global capture shortcut. If that matters, mark the dedicated frame with a
frame parameter when launching capture and test that parameter in the finalize
hook.

The plan's suggested `org-capture-initial-major-mode` and
`after-make-frame-functions` frame-parameter checks do not establish why a
frame was created.

### 3. The native-comp diagnosis and proposed hook are unsupported

The claimed chain from isearch in howm/Org, through
`package-native-compile`, to a silent startup crash has no evidence in the
source. `package-native-compile` controls ahead-of-time compilation during
package installation; it is not an isearch setting.

More decisively, `native-compiler-jit-fail` is neither a bound variable nor a
function in the installed Emacs 31.0.90. Adding it as a hook would create an
unused variable, and the proposed smoke test never forces native compilation
anyway. This section should be deleted, not implemented.

### 4. The no-littering lock-file warning is false

`no-littering-theme-backups` configures autosaves, backups, and undo-tree
history. It does not set `lock-file-name-transforms`. The current lock-file
form in `init.el:1189-1195` closely follows the installed no-littering README's
own example. There are not two competing lock mechanisms here.

### 5. The disposable Customize policy is already explicit

The plan presents the temporary `custom-file` as a surprise. It is an
intentional configuration-as-code policy documented in:

- `init.el:919-928`
- `readme.org:37-41`
- `status.org:19`
- `tasks.org:122-125`

`load-theme` occurring after the `setq` does not invalidate that policy.
Reversing the redirect would reintroduce state the repository deliberately
removed. No change is warranted unless the user wants to abandon the stated
policy.

### 6. `cl-defun` does not improve the font helper

Converting `scs/apply-default-font` to `cl-defun` would only provide Common
Lisp-style argument-list features. It would not make `'global` a meaningful
frame value or clarify the existing call sites.

Hermes missed the actual semantic mismatch. The docstring says a nil `frame`
applies the font globally, but `(or frame t)` passes `t` to
`set-face-attribute`. In Emacs, nil means all existing frames plus the default
for new frames; `t` changes only the default for new frames. Decide which
behavior is wanted and align the code and docstring. `cl-defun` is unrelated.

### 7. Which Function already works in Org

In a clean Emacs 31 process, an Org buffer with a `Parent` and `Child` heading
reported `"Child"` from `which-function`. Org supplies
`org-imenu-get-tree`, which is the relevant integration.

The suggested `which-func-imenu-cfg` variable does not exist in this Emacs
31 build. Pairing the feature with `imenu-list`, or disabling it in Org, would
solve a problem the probe could not reproduce.

### 8. Reloading already re-applies the Hyper translation

The `C-M-s-c` to `H-c` translation is in `init.el:1028-1029`.
`scs/reload-config` reloads `init.el`, so it re-evaluates that `define-key`.
The claim that it cannot be reapplied without restart is false. The early-init
modifier variables are a separate matter and are already documented as
restart-sensitive.

### 9. The server problem is real, but Hermes diagnosed the wrong problem

The FreeBSD collision described by Hermes cannot occur in the cited block
because the second-server form is guarded by `system-type` being `darwin`.

There is, however, a more important issue at `init.el:743-750`: both server
starts use the name `"server"`. The bundled Emacs `server-start` source stops
the current `server-process` before starting another. The second call therefore
does not create the independent socket-plus-TCP arrangement described by
`insights.org`; it can replace the Unix-socket server with the TCP server.

Live testing with Scrim 1.1.3 adds a constraint that source inspection alone
missed: the app accepts only an authentication file whose path ends in
`server/server`.  The two transports therefore need the same basename but
different directories: the ordinary listener uses the Unix socket
`server-socket-dir/server`, while Scrim uses the TCP authentication file
`user-emacs-directory/server/server`.  On Emacs 31, the second listener must
also have separately bound and retained `server-process` state; `server-start`
otherwise restarts the default listener.  Bind `server-auth-dir` explicitly
because no-littering changes its global value later during startup.

### 10. Several API and source references are simply wrong

- `:prefix "scs-"` is not a general Emacs Lisp namespace mechanism, and
  `:prefix` is not a top-level `use-package` keyword in this Emacs.
- `define-advice` does not create compatibility aliases. Use `defalias` or
  `define-obsolete-function-alias` when an alias is actually needed.
- The proposed howm extraction table says to remove helper code from
  `lisp/org-tools.el`; the `scs/howm-*` helpers are in `init.el`.
- The TRAMP test calls `(scs/tramp-hosts)` as though it were a function. It is
  a constant variable.
- The alleged `old-bell` block at `init.el:2686` is not there; that line is
  part of a Transient face specification.
- The commented `recentf-save-file` form is not live code.
- `org-tools.el` already explains its autoload policy, has autoload cookies on
  interactive entry points, and `init.el:244-251` declares matching explicit
  autoloads.

These are not harmless wording slips. They undermine the proposed file moves
and test tasks that depend on them.

### 11. The security section overstates one risk and misses better checks

`bin/authinfo-pass` prints a password because its PassCmd/passwordeval callers
require exactly that output. It does not log the password in its error paths,
and there is no `PASSWORDPROPERTY` use in the repository.

Useful security questions would instead be:

- Should the helper reject plaintext auth files with overly broad permissions?
- Must it support quoted or escaped netrc values?
- Should the setup use encrypted auth-source storage?
- Is the Gitea token file mode checked?

Also, the Gitea token is not read eagerly at startup as claimed. The
`use-package` declaration is command-deferred; the token is read in `:config`
when Gitea loads. A `loaded-at` timestamp would reveal load time, not token age,
so it cannot support a 30-day rotation warning.

### 12. Some performance advice would change policy, not merely optimize it

Fifty-two `use-package` declarations do not mean fifty-two packages are
loaded. `:commands`, `:bind`, `:hook`, `:after`, and `:defer` are already used
throughout the file.

The `company` suggestion would change global completion into prog-mode-only
completion. That may be desirable, but it is a UX decision, not a free loading
optimization. Likewise, a plain `display-graphic-p` guard around
`exec-path-from-shell` would skip daemon startup, where importing the GUI
environment can be most important. Any guard should explicitly account for
`daemonp`.

Adding MELPA Stable does not pin package versions, and most third-party packages
here are managed through el-get anyway. A daily ELN-cache deletion job would be
an unjustified destructive workaround.

## Useful ideas worth retaining

The plan is not devoid of value. These ideas merit a smaller, fresh plan:

1. Extract cohesive subsystems from `init.el`, especially howm/Org-ID, Helm fd,
   or el-get policy, when doing so creates a clean test boundary. Avoid a
   miscellaneous dumping-ground library merely to hit a line-count target.
2. Add focused tests for frame-state serialization and validation, howm slug
   generation, Org-ID collection, el-get error containment, and the authinfo
   parser. Test behavior with meaningful inputs; do not test constants merely
   to raise coverage.
3. Give reload-sensitive anonymous callbacks stable function names where
   removal or replacement matters.
4. Defer or remove packages that are truly installed and loaded but unused,
   notably `impatient-mode`, `keycast`, and `minions`.
5. Refresh `status.org` after verifying live behavior. Do not create
   `status.live.org` until there is a demonstrated automation need.
6. Keep the capture-frame intent question, but solve it with an explicit frame
   marker.

## Important issues Hermes missed

These deserve attention before most of its proposed polish:

1. **Dual server state:** retain distinct socket/TCP process state and
   transport directories so `bin/emacs-gui` and `bin/emacs-tty` keep using the
   default socket while Scrim gets its required `server/server` TCP auth file.
2. **`diff-hl` activation:** it has `:defer t` with no trigger that guarantees
   its `:config` runs, while `status.org` says global mode is on. Verify the live
   mode and either add a real trigger or stop claiming it is active.
3. **Stale bytecode in tests:** the current batch shape can load older `.elc`
   files. Make the future runner prefer newer source before adding more suites.
4. **Font helper contract:** align the nil-frame docstring with Emacs'
   `set-face-attribute` semantics.
5. **Abbrev scope:** `(abbrev-mode)` toggles the current buffer, not all future
   buffers. Emacs 31 has no `global-abbrev-mode`; if abbrev expansion is meant
   to be the default, use `(setq-default abbrev-mode t)`.

## Replacement priority list

**P0 — verify correctness**

- Inspect live socket and TCP server files/processes; keep their process state
  separate while honoring Scrim's required `server/server` auth-file path.
- Verify whether `global-diff-hl-mode` is actually active.
- Decide and test the font helper's nil-frame contract.

**P1 — improve verification**

- Add one deterministic test runner that sets `load-prefer-newer`.
- Add behavior tests for frame-state, howm naming/Org-ID, authinfo parsing, and
  the el-get safe-sync boundary.
- Mark capture-only frames explicitly.

**P2 — maintainability**

- Extract one cohesive subsystem at a time, with tests staying green through
  pure moves.
- Remove or defer unused eager packages.
- Refresh `status.org`; keep `plan.org` as rationale and `tasks.org` as the
  actionable list, which is already their documented division of responsibility.

**Reject**

- Global hook-reset machinery.
- The nonexistent native-comp failure hook.
- `cl-defun` as a font fix.
- Reversing the documented disposable `custom-file` policy.
- Org-specific Which Function workarounds.
- MELPA Stable as “pinning.”
- Daily ELN-cache deletion.
- The staged A–E plan in its present form.

## Change Log

- fix: 2026-07-27 -- incorporate Scrim 1.1.3's hard-coded server/server path
- fix: 2026-07-27 -- correct the Emacs 31 dual-server and abbrev API details
- add: 2026-07-26 -- fact-check Hermes plan and propose a smaller verified backlog

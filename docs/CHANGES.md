# Change register: php-5.6.40-php2shell.patch

This register lists every change in `patches/php-5.6.40-php2shell.patch`, where it comes
from, what it does, and how it compares with PHP's official fix. It also lists the parts
of the official fix that are not in this patch, and why.

## Sources

| Item | Value |
| --- | --- |
| Official fix | php-src commit [712e60f9edfd03f0960fc4fc3c2c375f42b90aa2](https://github.com/php/php-src/commit/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2), "Avoid state corruption via bailout", branch `PHP-7.4-CVE-2026-109618-109619` |
| PHP advisories | [GHSA-w8hw-w9fx-j79w](https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w) (CVE-2026-109618), [GHSA-6wmf-4rv5-p3rp](https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp) (CVE-2026-109619) |
| Starting point | An independent, unofficial open-source port of the official fix to PHP 5.4 (third party), reviewed line by line against the official fix |
| 5.6 adaptation | That 5.4 port applied to plain PHP 5.6.40, with two changes made by hand for 5.6 (C02 and C14 below) |
| Base source | PHP 5.6.40 from php.net, built with Webtatic's php56w recipe (the packages installed on the servers) |

"Upstream" links point to the changed lines in the official 7.4 fix. "Patch lines" are line
numbers in `patches/php-5.6.40-php2shell.patch`. The patch applies to PHP 5.6.40, after
Webtatic's own packaging patches, with no fuzz and no offsets.

The CVE column is the reviewer's reading of the code against PHP's descriptions of the two
vulnerabilities. CVE-2026-109618 is out-of-memory handling leaving request state
half-built. CVE-2026-109619 is request state surviving after its memory is freed.

## Changes in this patch

| ID | File and function | What it changes | Why | CVE | Upstream | Match | Patch lines |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C01 | `ext/session/session.c`, `php_session_rfc1867_callback()` | The upload progress handler always returns early | Switches off session upload progress, the known attack route on PHP 5, whatever php.ini says | 109619 | [L3177](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/ext/session/session.c#L3177) | Identical (`\|\| 1` here, `\|\| true` upstream) | 250-263 |
| C02 | `main/main.c`, ini table | Adds the `max_multipart_body_parts` setting, default -1 | Lets the upload parser cap the number of parts in a request | 109618 | [L839](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/main.c#L839) | Identical line; **placed by hand for 5.6**, after `max_file_uploads` | 296-303 |
| C03 | `main/main.c`, `php_request_shutdown()` | Clears the superglobal pointers and the modules-active flag at the end of each request | Stops the next request on the same worker touching freed data | 109619 | [L1964-L1965](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/main.c#L1964-L1965), [L2018-L2020](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/main.c#L2018-L2020) | Adapted: in PHP 5 the superglobals are plain pointers, cleared together at the end | 304-314 |
| C04 | `main/rfc1867.c`, `multipart_buffer_headers()` | Keeps only `Content-Disposition` and `Content-Type` per part, ignores duplicates, fixes a signed-char `isspace()` call | Limits how much memory a crafted upload can force PHP to use | 109618 | [L400-L407](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L400-L407), [L447-L457](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L447-L457) | Identical | 319-353 |
| C05 | `main/rfc1867.c`, `rfc1867_post_handler()` | Counts the parts in an upload and stops with a warning past the limit (default: max_input_vars + max_file_uploads) | Same | 109618 | [L711](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L711), [L733-L737](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L733-L737), [L822-L826](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L822-L826) | Identical | 354-387 |
| C06 | `main/SAPI.c`, `sapi_deactivate()` | Sets five request fields to NULL after freeing them | Removes dangling pointers between requests | 109619 | [L510-L529](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/SAPI.c#L510-L529) | Identical | 264-291 |
| C07 | `Zend/zend_alloc.c`, `zend_mm_panic()` | `exit(1)` becomes `_exit(1)` | Exits without running clean-up code that could touch corrupted memory | 109618 | [L367](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_alloc.c#L367) | Identical | 5-13 |
| C08 | `Zend/zend_alloc.c`, new `zend_mm_safe_error_ex()` | New function: prints the fatal error to stderr and calls `_exit(1)` | The core of the fix: never try to recover after running out of memory | 109618 | [L370-L402](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_alloc.c#L370-L402) | Adapted: uses PHP 5's functions for finding the current file and line | 14-54 |
| C09 | `Zend/zend_alloc.c`, `zend_mm_safe_error()` | Memory-limit and out-of-memory errors call `zend_mm_safe_error_ex()` instead of throwing an error and jumping back | Same; this handler is used by every memory-limit and out-of-memory path in PHP 5 | 109618 | [L414-L421](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_alloc.c#L414-L421) | Adapted: the PHP 5 version also had reserve-memory handling, no longer needed | 55-120 |
| C10 | `Zend/zend_alloc.c`, `safe_address()` (4 variants) | Allocation-size overflow checks call `zend_mm_safe_error_ex()` | Same | 109618 | [zend_multiply.h L324](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_multiply.h#L324), [L337](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_multiply.h#L337) | Adapted: in PHP 5 these checks live in zend_alloc.c | 121-156 |
| C11 | `Zend/zend_alloc.h` | Declares `zend_mm_safe_error_ex()` as a function that never returns | Needed by C08-C10, C14, C15 | 109618 | [L405-L406](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_alloc.h#L405-L406) | Adapted: PHP 5 has no `ZEND_NORETURN` macro, so the compiler attribute is written out | 157-176 |
| C12 | `Zend/zend_execute_API.c`, `shutdown_executor()` | Resets the error-handling mode and pending exception | Removes stale state that error handling could use before the next request starts | 109619 | [L351-L354](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_execute_API.c#L351-L354) | Identical; in 5.6 it lands after the engine stack is freed, which is the right point | 177-191 |
| C13 | `Zend/zend_llist.c`, `zend_llist_destroy()` | Sets the list's head and tail to NULL after destroying it | Removes dangling pointers | 109619 | [L115-L116](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_llist.c#L115-L116) | Identical | 192-204 |
| C14 | `Zend/zend_operators.c`, `concat_function()` | String-join overflow, in both branches, calls `zend_mm_safe_error_ex()` | Joining very long strings can't recover from a bad state | 109618 | [zend_vm_def.h L420](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_vm_def.h#L420), [L429-L431](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_vm_def.h#L429-L431) | **Adapted by hand for 5.6**: 5.6 already has the overflow check and uses `safe_emalloc()` in the second branch, so only the error handling changes there | 205-227 |
| C15 | `Zend/zend_strtod.c`, `Balloc()` | Number-parser allocation failures call `zend_mm_safe_error_ex()` | Same principle | 109618 | [L606](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_strtod.c#L606), [L619](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/Zend/zend_strtod.c#L619) | Adapted: PHP 5 also has a list-size check, which this patch converts too | 228-249 |

## Parts of the official fix not in this patch

| ID | Upstream change | Why it is not in this patch |
| --- | --- | --- |
| N01 | `main/rfc1867.c` `substring_conf()`: lengths changed from `int` to `size_t` ([L531](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L531), [L535](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L535), [L563](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L563), [L570](https://github.com/php/php-src/blob/712e60f9edfd03f0960fc4fc3c2c375f42b90aa2/main/rfc1867.c#L570)) | **Gap.** Not ported. Low risk, because `post_max_size` limits request size; planned for a later release |
| N02 | `Zend/zend_alloc.c`: `#include "zend_execute.h"` | PHP 5's zend_alloc.c already has what the new function uses |
| N03 | `Zend/zend_alloc.c`: debug-only size check in `zend_mm_alloc_heap()` | PHP 5 has no such check |
| N04 | `Zend/zend_alloc.c`: `zend_mm_alloc_huge()` | PHP 5 has no separate huge-block allocator |
| N05 | `Zend/zend_alloc.c`: overflow checks in `_estrdup()`, `_estrndup()`, `zend_strndup()` | PHP 5's versions have no overflow check to convert |
| N06 | `Zend/zend_alloc.c`: `zend_out_of_memory()` | PHP 5 has no such function; its out-of-memory path is C09 |
| N07 | `Zend/zend_execute_API.c`: reset of user error and exception handlers | PHP 5 already resets these in every shutdown |
| N08 | `Zend/zend_execute_API.c`: object store reset after fast shutdown | PHP 5 has no fast shutdown |
| N09 | `zend_hash.c`, `zend_hash.h`, `zend_types.h`, `zend_API.h`, `php_variables.c` | Code introduced in PHP 7.x, not present in PHP 5. Red Hat states the CVE-2026-109618 memory corruption is in that code |
| N10 | `Zend/zend_vm_execute.h` | Generated from zend_vm_def.h; the PHP 5 equivalent is C14 |

## Review sign-off

| Role | Name | Date | Result |
| --- | --- | --- | --- |
| Reviewer (optional) | | | |

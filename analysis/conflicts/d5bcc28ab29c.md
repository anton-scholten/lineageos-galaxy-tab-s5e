<!-- task: K2b-1 | agent: claude-opus-5 | date: 2026-10-03 -->
# d5bcc28ab29c: BACKPORT: net/ipv6: support more tunnel interfaces for EUI64 link-local generation
- Author / date: Felix Jia <felix.jia@alliedtelesis.co.nz>, 2017-01-26
- Upstream: `-` (no `commit <sha> upstream` / `Upstream commit <sha>` / `cherry picked from commit <sha>`
  trailer; only two `Signed-off-by:` lines)
- Batch: K2b-1, size_class: moderate
- Files in commit: `net/ipv6/addrconf.c` (+5: `case ARPHRD_IP6GRE:` in `addrconf_ifid_eui()`, three
  `(dev->type != ...)` checks in `addrconf_dev_config()`), `net/ipv6/ip6_gre.c` (+3),
  `net/ipv6/ip6_vti.c` (+4: `#include <linux/etherdevice.h>` + 3 lines in `vti6_dev_setup()`)

## Conflicting files
- `net/ipv6/addrconf.c` - **1 real block** (both in the isolated merge and in the reconstructed
  stacked replay, see below)
- auto-merged clean: `net/ipv6/ip6_gre.c`, `net/ipv6/ip6_vti.c`, and the first `addrconf.c` hunk

## Why it conflicts
`git merge-tree --write-tree --merge-base=d5bcc28ab^ a30605a54f3b d5bcc28ab` -> **conflicts**, tree
`970201d5377b`, only `net/ipv6/addrconf.c` (`CONFLICT (content)`, stages `a0657f5a82e9` /
`2034164c4343` / `d165e2d67911`).

- Block 1, `net/ipv6/addrconf.c` ~line 3230, in `addrconf_dev_config()` - the "we support only Ethernet
  autoconfiguration" early-return list:
  - ours (sdm670 `a30605a54f3b:net/ipv6/addrconf.c:3223-3229`): ends with
    `(dev->type != ARPHRD_NONE) && (dev->type != ARPHRD_RAWIP)) {` - sdm670 has an extra
    `ARPHRD_RAWIP` test that the Exy tree does not have.
  - theirs (`d5bcc28ab:net/ipv6/addrconf.c:3266-3272`): adds
    `(dev->type != ARPHRD_IP6GRE) && (dev->type != ARPHRD_IPGRE) && (dev->type != ARPHRD_TUNNEL) &&`
    before the existing `(dev->type != ARPHRD_NONE)) {`.
  - Both sides only *lengthen* the same condition list, so this is purely additive.
- Block 2 (does **not** conflict): the same commit's first hunk adds
  `case ARPHRD_IP6GRE:` to `addrconf_ifid_eui()` so IP6GRE reuses `addrconf_ifid_ip6tnl()`; it applies
  cleanly - verified at `970201d5377b:net/ipv6/addrconf.c:2145`
  (sdm670's `case ARPHRD_TUNNEL6:` is at `a30605a54f3b:net/ipv6/addrconf.c:2143`).
- Trial note: `conflict_detail.tsv` records **6 blocks / 15 ours / 10 theirs** for this commit. That count
  is inflated: `analysis/exyhyperbrick-trial/trial.py:30` commits trees that still contain `<<<<<<<`
  text, and the three earlier conflicted commits on this file (`5128fe02b819`, `580a9db663e1`,
  `18d6a9c0ea43`) all resolved into `net/ipv6/addrconf.c`. I rebuilt the stacked state by really
  merging them (sdm670 -> `5128fe02b819` -> `580a9db663e1` -> `18d6a9c0ea43`, keep-both resolutions,
  then `git merge-file -p --diff3` for this commit): **1 block**, byte-identical to block 1 above.

## Already in sdm670?
**No** (partly - the `ARPHRD_IP6GRE` *constant* is used, but none of this change is present).
Evidence searched:
- L1 `git grep -n 'ARPHRD_IP6GRE' a30605a54f3b -- net/ipv6/` -> 8 hits, **all in
  `a30605a54f3b:net/ipv6/ip6_gre.c`** (`:125`, `:136`, `:160`, `:186`, `:209`, `:317`, `:522`, `:1018`).
  **No hit in `net/ipv6/addrconf.c`** - the EUI64/autoconf side of the change is missing.
- L2 `git grep -n 'eth_random_addr(dev->perm_addr)' a30605a54f3b -- net/ipv6/` -> only
  `a30605a54f3b:net/ipv6/ip6_tunnel.c:1809`; **no hit in `ip6_gre.c` or `ip6_vti.c`**.
- L3 sdm670's `ip6gre_tunnel_setup()` ends at `netif_keep_dst(dev);`
  (`a30605a54f3b:net/ipv6/ip6_gre.c:1013-1022`) and `vti6_dev_setup()` likewise
  (`a30605a54f3b:net/ipv6/ip6_vti.c:893-903`) - neither sets `addr_assign_type`/`perm_addr`.
- Dependency check: `NET_ADDR_RANDOM` exists in sdm670 at
  `a30605a54f3b:include/uapi/linux/netdevice.h:60`, so the new lines compile.

## Proposed resolution
MERGE - one block, keep both sides (5 conditions):
```
	    (dev->type != ARPHRD_6LOWPAN) &&
	    (dev->type != ARPHRD_IP6GRE) &&      <- theirs
	    (dev->type != ARPHRD_IPGRE) &&       <- theirs
	    (dev->type != ARPHRD_TUNNEL) &&      <- theirs
	    (dev->type != ARPHRD_NONE) &&        <- common
	    (dev->type != ARPHRD_RAWIP)) {       <- ours, must NOT be dropped
```
Semantics check: the list is the set of devices that get IPv6 autoconfiguration, so both sides extend
it. Taking theirs whole would silently re-break RAWIP (sdm670 relies on that test), and taking ours
whole would drop GRE/tunnel EUI64 support. Keep both.
Take the rest of the commit exactly as auto-merged: `case ARPHRD_IP6GRE:` in `addrconf_ifid_eui()`, and
in `ip6_gre.c` / `ip6_vti.c` the `dev->addr_assign_type = NET_ADDR_RANDOM; eth_random_addr(dev->perm_addr);`
pair (plus `#include <linux/etherdevice.h>` in `ip6_vti.c`, already present at
`970201d5377b:net/ipv6/ip6_vti.c:52`).
Note for the reviewer: the five hunks are one unit - the `addrconf.c` list only helps if the tunnel
drivers own a random `perm_addr` to build the EUI-64 from.

## Confidence
high: single additive block, all three of the commit's `addrconf.c` hunks were located in the merged
tree, two greps plus a source read confirm sdm670 lacks the change, and I re-ran the merge against a
reconstructed stacked base to confirm the lead will meet exactly this one block.

## Problems
None

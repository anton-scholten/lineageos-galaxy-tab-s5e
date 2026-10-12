# boot-24-1 (2026-10-12): first LineageOS 24 boot, `enablefilecrypto_failed`. Excerpt of /proc/last_kmsg read from the 23.2 recovery (5529 lines). Full files kept locally (not committed: they contain device serials and MACs). Raw copy: `flash-logs/<timestamp>/`, git-ignored. Analysis: `analysis/l24/boot-24-1.md`.

Note: plain `grep` treats `last_kmsg` as binary and prints "binary file matches" — use `grep -a`.

```
4592:<14>[   15.185444]  [7:           init:    1] init: starting service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)'...
4594:<14>[   15.189072]  [7:           init:    1] init: ... started service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)' has pid 713
4595:<14>[   15.189176]  [7:           init:    1] init: SVC_EXEC service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)' pid 713 (uid 0 gid 0+0 context default) started; waiting...
4597:<15>[   15.198361]  [7:            vdc:  713] vdc: Waited 0ms for vold
4598:<11>[   15.212895]  [7:   binder:656_2:  656] vold: keystore2 Keystore generateKey returned service specific error: -67
4599:<12>[   15.212979]  [7:   binder:656_2:  656] vold: Failed to generate rollback-resistant key.  This is expected if keystore doesn't support rollback resistance.  Falling back to non-rollba
4600:<11>[   15.232462]  [6:   binder:656_2:  656] vold: Failed to install fscrypt key to /data: Inappropriate ioctl for device
4601:<12>[   15.232874]  [6:            vdc:  713] vdc: Command: cryptfs enablefilecrypto Failed: Status(-8, EX_SERVICE_SPECIFIC): '0: '
4603:<14>[   15.233793]  [6:           init:    1] init: Sending SIGKILL to service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)' (pid 713) process group...
4605:<11>[   15.234191]  [6:           init:    1] init: Exec service failed, status 25: Rebooting into recovery, reason: enablefilecrypto_failed
4606:<14>[   15.234267]  [6:           init:    1] init: Rebooting into recovery
4607:<14>[   15.236636]  [6:           init:    1] init: Got shutdown_command 'reboot,recovery' Calling HandlePowerctlMessage()
```

Lines 4598–4599 (keystore2 rollback-resistance) are expected noise; vold says so and falls back.
The failure is line 4600.

Two earlier boot markers for the record:

```
   79:<0>[  837.517790]  [0:           init:    1] reboot: Restarting system with command 'userrequested,recovery'
 1762:<3>[    1.650136]  [1:      swapper/0:    1] seemp: seemp_logk_init: SCM call failed with ret val = 0 -3 0
 3155:<3>[    2.462296]  [7:      swapper/0:    1] [drm-dp] secdp_init: DRM DP gpio request failed
 3727:<11>[    2.761940]  [6:           init:    1] init: [liblp] std::unique_ptr<LpMetadata> android::fs_mgr::ReadMetadata(const IPartitionOpener &, const std::string &, uint32_t) open failed: /dev/block/by-name/super: No such file or directory
 3734:<6>[    2.863203]  [0:      swapper/0:    0] SELinux: 32768 avtab hash slots, 89114 rules.
```
# boot-1 (2026-10-06): test boot.img, kernel 4.9.337-gcfe0b6979655 (port/no-btf), on BOOT. Excerpt of /proc/last_kmsg read from the 22.2 recovery. Full files kept by the owner (not committed: they contain device serials).

```
2041:<5>[    0.000000]  [0:        swapper:    0] Linux version 4.9.337-gcfe0b6979655 (nobody@android-build) (Android (14054515, +pgo, +bolt, +lto, +mlgo, based on r563880c) clang version 21.0.0 (http
<11>[    3.931303]  [0:           init:    1] init: [libfs_avb] Device path not found: /dev/block/by-name/vbmeta
<6>[    4.080068]  [6:    kworker/6:2:  174] sec_debug_partition:check_magic_data: start
<11>[    4.935672]  [0:           init:    1] init: [libfs_avb] Device path not found: /dev/block/by-name/boot
<11>[    4.935770]  [0:           init:    1] init: [libfs_avb] avb_slot_verify failed, result: 2
<11>[    4.935845]  [0:           init:    1] init: Failed to open AvbHandle for INIT_AVB_VERSION: No such file or directory
<14>[    4.953476]  [1:           init:    1] init: [libfstab] Using Android DT directory /proc/device-tree/firmware/android/
<14>[    4.954875]  [1:           init:    1] init: Skipping mount of system_ext, system is not dynamic.
<14>[    4.954944]  [1:           init:    1] init: Skipping mount of product, system is not dynamic.
<14>[    4.955026]  [1:           init:    1] init: Opening SELinux policy
<14>[    4.955089]  [1:           init:    1] init: Opening SELinux policy from monolithic file /sepolicy
<14>[    4.957310]  [1:           init:    1] init: Loading SELinux policy
<7>[    4.961474]  [6:           init:    1] SELinux: 32768 avtab hash slots, 80496 rules.
<6>[    4.961571]  [6:           init:    1] SELinux:  Android master kernel running Android M policy in compatibility mode.
<3>[    4.961634]  [6:           init:    1] SELinux: avtab: invalid type or class
<10>[    4.964052]  [6:           init:    1] init: SELinux:  Could not load policy: Invalid argument
<11>[    4.965368]  [6:           init:    1] init: InitFatalReboot: signal 6
<11>[    4.971981]  [6:           init:    1] init:   #00 pc 00000000000fac80  /system/bin/init (android::init::InitFatalReboot(int)+228) (BuildId: 8bb9a04f343037dd8a5d69df4cc06e3b)
<11>[    4.972090]  [6:           init:    1] init:   #01 pc 0000000000072bc0  /system/bin/init (android::init::InitAborter(char const*)+48) (BuildId: 8bb9a04f343037dd8a5d69df4cc06e3b)
<11>[    4.972207]  [6:           init:    1] init:   #02 pc 000000000001454c  /system/lib64/libbase.so (android::base::SetAborter(std::__1::function<void (char const*)>&&)::$_0::__invoke(char const*)+80) (BuildId: 46bc0
<11>[    4.972336]  [6:           init:    1] init:   #03 pc 0000000000013a4c  /system/lib64/libbase.so (android::base::LogMessage::~LogMessage()+548) (BuildId: 46bc013aa374f7f1951477f848c2574e)
<11>[    4.972438]  [6:           init:    1] init:   #04 pc 00000000000fed7c  /system/bin/init (android::init::SetupSelinux(char**)+8476) (BuildId: 8bb9a04f343037dd8a5d69df4cc06e3b)
<11>[    4.972533]  [6:           init:    1] init:   #05 pc 00000000000664cc  /system/lib64/libc.so (__libc_init+120) (BuildId: 9d3c9a4206374b556654d838f3ec4b25)
<14>[    4.972614]  [6:           init:    1] init: Reboot ending, jumping to kernel
<3>[    4.972769]  [6:           init:    1] set_dload_mode <0> ( ffffff8008c6dd58 )
<3>[    4.972847]  [6:           init:    1] set_dload_mode <0> ( ffffff80092b4648 )
<3>[    4.972891]  [6:           init:    1] (sec_debug_set_upload_magic) 0
<3>[    4.973205]  [0:dbmdx probe thr:  378] dbmdx-codec soc:dbmdx: dbmdx_request_and_load_fw: failed to request VA firmware
<0>[    5.099370]  [0:           init:    1] reboot: Restarting system with command 'bootloader'
<5>[    5.099447]  [0:           init:    1] Going down for restart now
<6>[    5.099503]  [0:           init:    1] PM0: PON:81 ON:80 POFF:20 O:80 F1:00 F2:00 S3:00
<6>[    5.099503]  [0:           init:    1] PM1: PON:20 ON:80 POFF:08 O:80 F1:00 F2:00 S3:00
<0>[    5.100205]  [0:           init:    1] qcom,qpnp-power-on c440000.qcom,spmi:qcom,pm660l@2:qcom,power-on@800: PMIC@SID2: configuring PON for reset
<3>[    5.100865]  [0:           init:    1] (sec_debug_update_restart_reason) unknown reboot command : bootloader
```

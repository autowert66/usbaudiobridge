# UsbAudioBridge SELinux Policy (KernelSU module)

Grants the UsbAudioBridge app access to the USB-gadget ALSA device, so its native
bridge can open `/dev/snd/pcmC1D0c` and `/dev/snd/pcmC1D0p`.

## Symptom this fixes

With the gadget up and capture running, the in-app log repeats this for every
period-size x period-count combination and the bridge never starts:

```
[Native] Config 2048 x 4 failed: cannot open device (0) for card (1): Permission denied
[Native] All configs failed. Retrying in 1s...
```

The kernel audit shows the reason:

```
avc: denied { search } for name="snd" dev="tmpfs" ino=677
  scontext=u:r:untrusted_app_34:s0:c180,c257,c512,c768
  tcontext=u:object_r:audio_device:s0 tclass=dir permissive=0
```

`chmod 666` on the device node does not help: the denial is SELinux (MAC), not file
permissions.

## Why a module

`UsbGadgetManager.applySeLinuxPolicy()` adds rules for the source type
`untrusted_app`, but the app runs in `untrusted_app_34` (its `targetSdk` is 36, and
`untrusted_app_34` is the highest `untrusted_app_NN` domain). A rule on
`untrusted_app` does not match `untrusted_app_34`, so it has no effect.

This module applies the same rules against the correct domain, and KernelSU loads
`sepolicy.rule` at boot via `ksud`'s `load_sepolicy_rule()`.

## Install

Flash the module zip with the KernelSU / KernelSU-Next manager, or copy this
directory to `/data/adb/modules/usbaudiobridge_selinux/` and reboot. The files should
be owned by `root:root` and labeled `u:object_r:system_file:s0`, like other modules.

## Enable / disable

`ksud` only loads `sepolicy.rule` for active modules, so the module is the on/off
switch:

```sh
touch /data/adb/modules/usbaudiobridge_selinux/disable   # then reboot
```

There is no way to unload a single rule from a running policy, so toggling takes
effect only after a reboot.

## Root-hiding notes

- The rules live only in the kernel's loaded SELinux policy. They add no files, no
  mounts and no processes, so there is nothing on disk to hide for the rules
  themselves.
- The module directory is under `/data/adb/` (root-only) and is hidden by KernelSU
  together with SUSFS / NoMount.
- Residual vector: `/sys/fs/selinux/policy` is world-readable (`0444`) on this
  device, so a detector that reads the loaded binary policy and diffs it against a
  reference could observe the added rules. The rules are unremarkable and this is not
  a technique mainstream integrity checks use.
- The grant is broader than one app: every app targeting SDK 34+ shares the
  `untrusted_app_34` domain. That is the same grant `applySeLinuxPolicy()` attempts,
  and it is inherent to opening the gadget PCM from app context. Avoiding it requires
  running the bridge out-of-process as root.

## If the domain changes

If a future app build changes `targetSdk` such that the SELinux domain is no longer
`untrusted_app_34`, update the source type in `sepolicy.rule`. Check the current
domain with:

```sh
ps -A -o LABEL,NAME | grep usbaudiobridge
```

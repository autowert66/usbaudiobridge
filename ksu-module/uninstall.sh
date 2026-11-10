#!/system/bin/sh
# Nothing to undo.
#
# The rules in sepolicy.rule live only in the kernel's loaded SELinux policy. They are
# not written to disk and are discarded on reboot, so removing this module leaves no
# trace once the device is rebooted.
#
# There is no supported way to remove a single rule from a running policy, so if the
# grant must disappear immediately, reboot.
exit 0

#!/bin/sh
# bluejay: Trusty's secure storage app hits an internal consistency
# assertion trying to use two specific backing files -
#     Assert fail: !block_cache_entry_data_is_dirty(entry)
#         (block_cache.c: block_get_cleared_super: 1536)
# - which Trusty treats as fatal to the whole secure OS ("panic (caller
# 0x***): Unclean exit from critical app", "HALT: (reason = 9)"), taking
# the kernel down with it (SMC_SC_NOP failed -11, "Kernel panic - not
# syncing: trusty crashed"). See bluejay-audio-blocker-SOLVED and
# bluejay-trusty-storage-panic-root-cause in project memory for the full
# trace - this was the actual audio blocker, not tipc/virtio ordering.
#
# Both files predate this LuneOS boot (this device's bootloader reports
# verifiedbootstate=orange/unlocked, and Trusty's own filesystem checks do
# not tolerate data sealed under a different boot state) and/or carry
# partial writes from any earlier crashed boot attempt. Once Trusty
# actually crashes trying to use them there is nothing left they are good
# for - moving them aside lets Trusty format fresh storage instead.
#
# Idempotent (checks each path still has its original name before acting),
# so this is safe to run on every boot rather than needing a run-once
# stamp file - if a future userdata/vendor.img reflash restores the stale
# files, this fixes it again on the very next boot instead of silently
# reintroducing the crash.
#
# mv, not rm: moving aside is enough to get Trusty to treat the path as
# absent and format fresh, and keeps the original bytes on disk rather
# than discarding them irreversibly for no operational benefit.

# This ships in the generic halium-arm64 rootfs, which boots every arm64 Halium
# device, so it has to identify the device itself. It runs before the Android
# container, so getprop is not available yet and neither is luneos-device-config's
# /run/luneos-device - the device tree is, from the first moment of boot:
#     $ tr '\0' '\n' < /proc/device-tree/compatible
#     google,GS101 BLUEJAY
#     google,GS101
# Anything else leaves secure storage alone. Other Tensor devices reach the same
# Trusty code but have not been shown to need this, and moving another device's
# secure storage aside on a guess is not a safe default.
if ! tr '\0' '\n' < /proc/device-tree/compatible 2>/dev/null | grep -qi 'BLUEJAY'; then
    exit 0
fi

for f in /android/data/vendor/ss/0 /mnt/vendor/persist/ss/0; do
    if [ -f "$f" ]; then
        mv "$f" "$f.stale-pre-luneos"
        echo "bluejay-trusty-storage-fixup: moved aside $f" > /dev/kmsg
    fi
done

exit 0

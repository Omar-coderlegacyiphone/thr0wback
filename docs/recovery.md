# Recovery

## The phone cannot be permanently bricked

The iPhone 4's bootrom is read-only and always offers **DFU mode**, and the
**limera1n** exploit in it can't be patched. Whatever happens during a boot, the
host can always reach the phone and restore it. Thr0wback never changes that.

## What is actually at risk: the untethered 4.1 install

The 4.1 install was produced by an untethered downgrade with **Legacy iOS Kit**
(most likely powdersn0w). That means the bootloaders on the phone's NAND are
patched ones that make 4.1 boot untethered — they are *not* the stock 4.1
bootloaders. Two rules follow:

1. **Never overwrite the on-NAND bootloaders (LLB / iBoot).** The experimental
   OS boots from host RAM over USB and never writes a bootchain to NAND. Keep it
   that way.
2. **Never flash the baseband.** It is not touched by any step here.

If the 4.1 install is damaged (e.g. by a partition step gone wrong), the fix is
to **re-run Legacy iOS Kit** to redo the untethered downgrade. So the one backup
worth keeping is the **Legacy iOS Kit folder** used originally, with its saved
files — don't delete it.

## If a tethered boot hangs

- Hold Power + Home to force a reboot; the phone comes back into untethered 4.1.
- Or enter DFU and let the host take over.

A hung tethered boot writes nothing permanent, so there's nothing to undo.

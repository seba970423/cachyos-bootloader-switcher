#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SWITCHER_RELEASE="r47"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/storage.sh"
source "$SCRIPT_DIR/lib/detect.sh"
source "$SCRIPT_DIR/lib/kernels.sh"
source "$SCRIPT_DIR/lib/validate.sh"
source "$SCRIPT_DIR/lib/limine_validate.sh"
source "$SCRIPT_DIR/lib/grub_validate.sh"
source "$SCRIPT_DIR/lib/systemd_boot_validate.sh"
source "$SCRIPT_DIR/lib/refind_validate.sh"
source "$SCRIPT_DIR/lib/backup.sh"

bootloader_display_name() {
    case "$1" in
        grub) printf 'GRUB' ;;
        limine) printf 'Limine' ;;
        refind) printf 'rEFInd' ;;
        systemd-boot) printf 'systemd-boot' ;;
        *) printf '%s' "$1" ;;
    esac
}

source "$SCRIPT_DIR/lib/operations.sh"
source "$SCRIPT_DIR/lib/staged.sh"
source "$SCRIPT_DIR/lib/r21.sh"
source "$SCRIPT_DIR/lib/r22.sh"
source "$SCRIPT_DIR/lib/r23.sh"
source "$SCRIPT_DIR/lib/restore.sh"
source "$SCRIPT_DIR/lib/r25.sh"
source "$SCRIPT_DIR/lib/r26.sh"
source "$SCRIPT_DIR/lib/r27.sh"
source "$SCRIPT_DIR/lib/r28.sh"
source "$SCRIPT_DIR/lib/r29.sh"
source "$SCRIPT_DIR/lib/r30.sh"
source "$SCRIPT_DIR/lib/r31.sh"
source "$SCRIPT_DIR/lib/r32.sh"
source "$SCRIPT_DIR/lib/r33.sh"
source "$SCRIPT_DIR/lib/r34.sh"
source "$SCRIPT_DIR/lib/r35.sh"
source "$SCRIPT_DIR/lib/r36.sh"
source "$SCRIPT_DIR/lib/r37.sh"
source "$SCRIPT_DIR/lib/r38.sh"
source "$SCRIPT_DIR/lib/r39.sh"
source "$SCRIPT_DIR/lib/r40.sh"
source "$SCRIPT_DIR/lib/r41.sh"
source "$SCRIPT_DIR/lib/r42.sh"
source "$SCRIPT_DIR/lib/r43.sh"
source "$SCRIPT_DIR/lib/r44.sh"
source "$SCRIPT_DIR/lib/r45.sh"
source "$SCRIPT_DIR/lib/r46.sh"
source "$SCRIPT_DIR/lib/r47.sh"

select_target_bootloader() {
    local choice target current_name
    detect_bootloader
    current_name=$(bootloader_display_name "$BOOTLOADER")

    while true; do
        printf '\nCurrent bootloader: %s\n\n' "$current_name"
        printf 'Select target bootloader:\n\n'
        printf '[1] GRUB%s\n' "$([[ $BOOTLOADER == grub ]] && printf ' (repair/reinstall)' || true)"
        printf '[2] Limine%s\n' "$([[ $BOOTLOADER == limine ]] && printf ' (current)' || true)"
        printf '[3] systemd-boot%s\n' "$([[ $BOOTLOADER == systemd-boot ]] && printf ' (current)' || true)"
        printf '[4] rEFInd%s\n' "$([[ $BOOTLOADER == refind ]] && printf ' (current)' || true)"
        printf '[5] Back\n\n'
        read -r -p 'Select a bootloader: ' choice
        [[ -n $choice ]] || { printf '\nPlease select an option.\n'; continue; }

        case "$choice" in
            1) target=grub ;;
            2) target=limine ;;
            3) target=systemd-boot ;;
            4) target=refind ;;
            5) return 0 ;;
            *) printf '\nInvalid selection.\n'; continue ;;
        esac

        printf '\nSelected target: %s\n' "$(bootloader_display_name "$target")"
        if [[ $target == "$BOOTLOADER" ]]; then
            if [[ $target == grub ]]; then
                printf 'Planned operation: repair/reinstall current bootloader\n'
            else
                printf 'Planned operation: current-bootloader repair is not enabled for %s yet\n' "$(bootloader_display_name "$target")"
            fi
        else
            printf 'Planned operation: staged switch %s -> %s\n' "$current_name" "$(bootloader_display_name "$target")"
        fi
        run_live_operation "$target"
        return $?
    done
}

main_menu() {
    local choice

    while true; do
        clear 2>/dev/null || true
        printf 'CachyOS Bootloader Switcher — %s adapter transaction framework\n\n' "$SWITCHER_RELEASE"
        print_system_report
        printf '\n'
        pending_banner
        pending_exists && printf '\n'
        r22_show_last_auto_result
        discover_backups_quiet
        if ((${#DISCOVERED_BACKUPS[@]} > 0)); then
            printf 'Detected backups: %d\n' "${#DISCOVERED_BACKUPS[@]}"
        else
            printf 'Detected backups: none\n'
        fi
        printf '\n'
        printf '[1] Select bootloader to switch/repair\n'
        printf '[2] Manage pending/staged migration\n'
        printf '[3] Create backup of currently booted bootloader\n'
        printf '[4] List and validate backups\n'
        printf '[5] Restore a validated backup\n'
        printf '[6] Show restore plan for a backup (read-only)\n'
        printf '[7] Deep-validate current boot chain (read-only)\n'
        printf '[8] Refresh detection\n'
        printf '[9] Exit\n\n'
        read -r -p 'Select an option: ' choice
        [[ -n $choice ]] || continue

        case "$choice" in
            1) select_target_bootloader; pause ;;
            2) manage_pending_migration; pause ;;
            3) create_current_bootloader_backup_interactive; pause ;;
            4) list_backups_interactive; pause ;;
            5) restore_backup_interactive; pause ;;
            6) restore_plan_interactive; pause ;;
            7)
                detect_bootloader
                case "$BOOTLOADER" in
                    limine) run_validation preflight && validate_limine_boot_chain current && { if grep -Fqx "# CachyOS Limine theme" "${ESP_MOUNT:-/boot}/limine.conf" 2>/dev/null; then validate_cachyos_limine_theme; else true; fi; } ;;
                    grub) run_validation preflight && validate_grub_boot_chain current && { if pacman -Q cachyos-grub-theme >/dev/null 2>&1 || grep -Eq '^[[:space:]]*GRUB_THEME=' /etc/default/grub 2>/dev/null; then validate_cachyos_grub_theme; else true; fi; } ;;
                    systemd-boot) run_validation preflight && validate_systemd_boot_chain current ;;
                    refind) run_validation preflight && validate_refind_boot_chain current ;;
                    *) printf '\nA deep boot-chain validator is not implemented for %s yet.\n' "$(bootloader_display_name "$BOOTLOADER")" ;;
                esac
                pause
                ;;
            8) : ;;
            9) exit 0 ;;
            *) printf '\nInvalid selection.\n'; pause ;;
        esac
    done
}

if [[ ${EUID:-$(id -u)} -eq 0 && ${1:-} != --resume-transaction-root ]]; then
    printf 'Do not run the whole tool as root. Run it as your normal user.\n' >&2
    printf 'Modifying operations elevate only the commands that need it.\n' >&2
    exit 1
fi

case "${1:-}" in
    --resume-transaction-root)
        [[ ${EUID:-$(id -u)} -eq 0 ]] || die '--resume-transaction-root is an internal root-only automatic-resume action'
        r22_resume_transaction_root
        ;;
    --report) print_system_report ;;
    --validate) run_validation passive ;;
    --list-backups) list_backups ;;
    --validate-limine)
        detect_bootloader
        run_validation preflight && validate_limine_boot_chain current
        ;;
    --validate-grub)
        detect_bootloader
        run_validation preflight && validate_grub_boot_chain current && { if pacman -Q cachyos-grub-theme >/dev/null 2>&1 || grep -Eq '^[[:space:]]*GRUB_THEME=' /etc/default/grub 2>/dev/null; then validate_cachyos_grub_theme; else true; fi; }
        ;;
    --validate-systemd-boot)
        detect_bootloader
        run_validation preflight && validate_systemd_boot_chain current
        ;;
    --validate-refind)
        detect_bootloader
        run_validation preflight && validate_refind_boot_chain current
        ;;
    --manage-staged) manage_pending_migration ;;
    --help|-h)
        cat <<'HELP'
Usage: ./bootloader-switcher.sh [OPTION]

Without options, opens the interactive current-release menu.

  --report          print passive read-only system/bootloader detection
  --validate        run passive validation checks (never authenticates)
  --list-backups    discover and validate backups in the user's home directory
  --validate-limine deep read-only validation of the active/generated Limine boot chain
  --validate-grub   deep read-only validation of the active/generated GRUB boot chain
  --validate-systemd-boot deep read-only validation of systemd-boot
  --validate-refind deep read-only validation of rEFInd
  --manage-staged   inspect/revalidate/arm/runtime-check/rollback a pending candidate
  --help            show this help

CURRENT MODIFYING BACKENDS:
  - GRUB -> GRUB repair/reinstall
  - hardware-proven automated GRUB <-> CachyOS-themed Limine
  - adapter transactions: hardware-proven GRUB <-> systemd-boot and GRUB <-> rEFInd
  - r39-clean rEFInd -> Limine live migration with transactional inactive-residue preservation and post-retirement menu reconciliation (hardware-proven)
  - r40 direct Limine -> rEFInd live migration (hardware-proven)
  - complete four-bootloader live migration matrix (hardware-proven on real firmware)
  - r43 rEFInd <-> systemd-boot v4 backup restore (hardware-proven on real firmware)
  - r44 rEFInd -> restored GRUB v3/v4 backup restore (enabled for hardware testing)
  - r45 VFAT-safe GRUB -> restored Limine v4 payload restore hotfix
  - r46 complete 12-edge cross-restore support-predicate consistency
  - r47 effective multi-assignment Limine backup cmdline reconstruction
  - r38 transactional Limine -> restored-rEFInd v4 and rEFInd -> restored-Limine v3/v4 backup restore (enabled for hardware testing)
  - automatic BootNext + temporary root-owned systemd resume for supported cross-family migrations
  - runtime proof before destructive source retirement
  - ownership-gated finalization and post-cleanup deep validation
  - validated GRUB and Limine backup restore
  - r28/r29 transactional systemd-boot v4 restore from a verified GRUB source (hardware-proven)
  - r35 transactional rEFInd v4 restore from a verified GRUB source (hardware-proven)

r41 opened the four remaining direct live systemd-boot/non-GRUB edges; all four have now completed real-firmware runtime proof/finalization.
r43 opened the rEFInd <-> systemd-boot v4 backup-restore pair; both directions subsequently completed real-firmware runtime proof/finalization.
r44 closes the separate restore-dispatch gap exposed by sequential sanity testing: rEFInd -> restored GRUB v3/v4.
r45 fixes the historical GRUB -> restored-Limine v4 tunnel so the managed payload is copied to the VFAT ESP without attempting unsupported Unix ownership/mode preservation.
r46 aligns the internal cross-restore support predicate with the already-functional 12-edge interactive restore dispatcher by admitting GRUB -> restored rEFInd.
r47 fixes Limine backup restore preflight when /etc/default/limine expresses one effective default cmdline across multiple KERNEL_CMDLINE[default]+= assignments.
r40 enabled and subsequently hardware-proved the previously separate Limine -> rEFInd live migration path.
r38 enables the bidirectional Limine <-> rEFInd backup-restore edge.
r37 allows the rEFInd -> Limine live edge to preserve/clear inactive Limine filesystem residue transactionally instead of requiring a pristine target namespace; pre-existing canonical Limine NVRAM entries remain refused as ambiguous.
r36 originally opened the first direct non-GRUB live edge (rEFInd -> Limine); r39/r40 later supplied the clean hardware proof, while release labels derive from SWITCHER_RELEASE.
r35 enables transactional GRUB -> restored-rEFInd v4 backup restore and fixes stale/misleading manual transaction-result bookkeeping.
r34 fixes the nounset/dynamic-scope pkgbase failure exposed by rEFInd runtime proof and hardens the remaining active same-class local initializers.
r33 fixes the first real rEFInd runtime-certification false negative: EFI/refind/vars is mutable rEFInd state, and PreviousBoot now proves a direct CachyOS kernel launch rather than a GRUB chainload.
r29 fixes the first real-hardware systemd-boot restore staging failure: a set -u/local expansion bug in the backup ESP path helper.
r27 keeps the r26 adapter transaction engine intact and fixes backup metadata parsing for labels/paths serialized with Bash printf %q (including the systemd-boot label "Linux Boot Manager").
The systemd-boot live adapter currently requires ESP=/boot because CachyOS sdboot-manage scans the ESP root for vmlinuz-*; other topologies are refused rather than rewritten.
No operation rewrites /etc/fstab or forces a Calamares-style ESP mountpoint.
A cross-family stage parks a deeply validated candidate while the source remains first in persistent BootOrder.
For fresh GRUB <-> Limine migrations and supported backup restores, the switcher arms BootNext automatically after candidate validation and prompts before reboot.
A temporary root-owned systemd service resumes the exact transaction after reboot, validates the target, and finalizes only after all ownership/runtime gates pass.
The Limine target uses the captured CachyOS palette plus /boot/limine-splash.png instead of the generic Limine appearance.
HELP
        ;;
    '') main_menu ;;
    *) die "Unknown option: $1" ;;
esac

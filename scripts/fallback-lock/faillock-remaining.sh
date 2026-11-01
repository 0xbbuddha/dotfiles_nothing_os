#!/bin/sh
conf=/etc/security/faillock.conf

value() {
    sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([0-9]*\).*/\1/p" "$conf" 2>/dev/null | tail -n 1
}

deny=$(value deny)
interval=$(value fail_interval)
unlock=$(value unlock_time)

faillock --user "$(id -un)" 2>/dev/null | awk \
    -v now="$(date +%s)" \
    -v deny="${deny:-3}" \
    -v interval="${interval:-900}" \
    -v unlock="${unlock:-600}" '
    $NF == "V" {
        stamp = $1 " " $2
        gsub(/[-:]/, " ", stamp)
        when = mktime(stamp)
        if (now - when <= interval) {
            count++
            if (when > last)
                last = when
        }
    }
    END {
        if (count >= deny && (unlock == 0 || now - last < unlock))
            print (unlock == 0 ? 0 : unlock - (now - last))
    }'

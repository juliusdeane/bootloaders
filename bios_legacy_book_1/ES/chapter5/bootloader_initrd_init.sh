#!/bin/sh
# Bootloader init:
# - init mínimo que gestiona el apagado.

echo
echo "[INIT] Sistema iniciado:"
# Montamos recursos administrativos de Linux
# - con /proc funcionará ps
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Abrimos el shell, claro.
echo "[INIT] Lanzando shell interactiva (PID 1):"
# Hemos comentado la línea de abajo:
/bin/sh

# (1) Hemos quitado el comentario a la línea con exec:
# Asignar /dev/ttyS0 como tty de control
# exec setsid sh -c 'exec sh </dev/ttyS0 >/dev/ttyS0 2>&1'

# (2) Lograr que funcione!
# - Quita el comentario para tener el init.sh perfecto :)
# - Comenta (1) y /bin/sh
# setsid sh -c 'exec sh </dev/ttyS0 >/dev/ttyS0 2>&1'

# Al salir del shell, apagamos de forma controlada.
echo "[INIT] Shell terminada, apagando de forma controlada..."
sync
poweroff -f

# NOTA:
# - Si poweroff no está disponible (no tenemos el enlace o
# por lo que fuera busybox no lo soporta, puedes hacerlo con:
# (quita el comentario a las líneas siguientes)
# echo "[init] Forzando apagado mediante sysrq"
# echo o > /proc/sysrq-trigger

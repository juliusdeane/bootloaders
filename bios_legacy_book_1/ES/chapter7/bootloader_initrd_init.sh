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

setsid sh -c 'exec sh </dev/ttyS0 >/dev/ttyS0 2>&1'
#setsid sh -c 'exec sh </dev/tty0 >/dev/tty0 2>&1'

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

#!/bin/sh
# Bootloader init:
# - init mínimo que gestiona el apagado.

echo "[INIT] Iniciando (cons)" > /dev/console
echo "[INIT] Iniciando (TTY0)" > /dev/tty0 2>/dev/null
echo "[INIT] Iniciando (TTY1)" > /dev/tty1 2>/dev/null
echo "[INIT] Iniciando (COM1)" > /dev/ttyS0 2>/dev/null

echo
echo "[INIT] Sistema iniciado:"
# Montamos recursos administrativos de Linux
# - con /proc funcionará ps
echo
echo "[INIT] [PROC/SYS/DEV] Montamos /proc, /sys, /dev:"
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Danos tiempo a que las cosas se configuren.
sleep 5

echo "[INIT] [NETWORK] Intentamos obtener una IP:"
# Configurar loopback
echo "    => loopback up:"
ip link set lo up

# Levantar la interfaz de red (ajusta 'eth0' según tu interfaz)
echo "    => eth0 up:"
ip link set eth0 up

# Pedir IP por DHCP
echo "    => DHCP client (eth0):"
udhcpc -i eth0

echo "[INIT] [NETWORK] Completado ==================================================<"

echo "[INIT] Redirigimos a consola:"
exec </dev/tty0 >/dev/tty0 2>&1

echo "[INIT] Lanzando shell interactiva (PID 1):"
# Abrimos el shell.
setsid sh -c 'exec sh -l </dev/tty0 >/dev/tty0 2>&1'

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
